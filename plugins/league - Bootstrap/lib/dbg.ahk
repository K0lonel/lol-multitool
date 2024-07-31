#Requires AutoHotkey v2.0
objView(Obj, NewRow := "`n", Equal := "  =  ", Indent := "`t", Depth := 12, CurIndent := "")
{
    for k,v in Obj
        ToReturn .= CurIndent . k . (IsObject(v) && depth>1 ? NewRow . objView(v, NewRow, Equal, Indent, Depth-1, CurIndent . Indent) : Equal . v) . NewRow
    return RTrim(ToReturn, NewRow)
}