#Requires AutoHotkey v2.0
#Include LCU.ahk
global req := ComObject("WinHttp.WinHttpRequest.5.1")

APICall(method, endpoint, post_data := "") {
    static headersIn := Map("Authorization", "Basic " LCU.Token)
    endpoint := LCU.App_URL endpoint

    return request(method, endpoint, post_data, headersIn)
}

request(method, endpoint, post_data, headersIn := Map()) {
    static headers := Map("Content-Type", "application/json", "Accept", "application/json")

    req.Open(method, endpoint, False)
    for k, v in headersIn
        headers[k] := v
    for k, v in headers
        req.SetRequestHeader(k, v)
    req.Option[4] := 0x3300
    req.Send(post_data)

    pSafeArray := req.ResponseBody
    if(IsObject(pSafeArray)){
	    pvData := NumGet(ComObjValue(pSafeArray) + 8 + A_PtrSize, "ptr")
	    cbElements := pSafeArray.MaxIndex() + 1
	    return JSON.Load(StrGet(pvData, cbElements, "UTF-8"))
    }
    return pSafeArray
}