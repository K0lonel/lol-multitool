#Requires AutoHotkey v2.0
#Include LCU.ahk
APICall(method, endpoint, post_data := unset) {
    if (LCU.Token == "") {
        if (!LCU.Initialize()) {
            return Map("error", "Offline", "status", 0)
        }
    }
    headersIn := Map("Authorization", "Basic " LCU.Token)
    url := LCU.App_URL endpoint

    return request(method, url, post_data?, headersIn)
}

request(method, endpoint, post_data?, headersIn := Map()) {
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    headers := Map("Content-Type", "application/json", "Accept", "application/json")

    req.Open(method, endpoint, False)
    ; Set resolve/connect/send/receive timeouts in milliseconds
    ; (Resolve: 5s, Connect: 5s, Send: 5s, Receive: 5s) to prevent script freeze
    req.SetTimeouts(5000, 5000, 5000, 5000)

    for k, v in headersIn
        headers[k] := v
    for k, v in headers
        req.SetRequestHeader(k, v)
    req.Option[4] := 0x3300

    try {
        if IsSet(post_data)
            req.Send(post_data)
        else
            req.Send()
        status := req.Status
        if (status == 429) {
            LogToWeb("LCU API Rate Limit (429) on " method " " endpoint, "warning")
            return Map("error", "RateLimit", "status", 429)
        }
        if (status >= 400) {
            if (status != 404) {
                LogToWeb("LCU API Error " status " on " method " " endpoint, "error")
            }
            return Map("error", "HTTPError", "status", status)
        }
        pSafeArray := req.ResponseBody
        if(IsObject(pSafeArray)){
            pvData := NumGet(ComObjValue(pSafeArray) + 8 + A_PtrSize, "ptr")
            cbElements := pSafeArray.MaxIndex() + 1
            bodyStr := StrGet(pvData, cbElements, "UTF-8")
            if (bodyStr == "") {
                return Map()
            }
            try {
                return JSON.Load(bodyStr)
            } catch Error as jsonErr {
                LogToWeb("LCU API JSON Parse Error: " jsonErr.Message " on response: " SubStr(bodyStr, 1, 100), "warning")
                return Map("error", "JSONError", "message", jsonErr.Message, "status", status)
            }
        }
    } catch Error as e {
        static lastErrTime := 0
        if (A_TickCount - lastErrTime > 15000) {
            LogToWeb("LCU API offline or refused connection: " e.Message, "warning")
            lastErrTime := A_TickCount
        }
        LCU.Token := ""
        return Map("error", "Offline", "status", 0)
    }

    return pSafeArray
}