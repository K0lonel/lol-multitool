#Requires AutoHotkey v2.0
Class Base64 {
	/**
	 * Base64编码
	 * @param Buf Buffer Object has Ptr, Size Property. May contain any binary contents including NUll bytes.
	 * @param Codec CRYPT_STRING_BASE64 0x00000001
	 * CRYPT_STRING_NOCRLF 0x40000000
	 * @returns Base64 String if success, otherwise blank.
	 */
	static Encode(String, Encoding := "UTF-8") {
		static CRYPT_STRING_BASE64 := 0x00000001
		static CRYPT_STRING_NOCRLF := 0x40000000

		Binary := Buffer(StrPut(String, Encoding))
		StrPut(String, Binary, Encoding)
		if !(DllCall("crypt32\CryptBinaryToStringW", "Ptr", Binary, "UInt", Binary.Size - 1, "UInt", (CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF), "Ptr", 0, "UInt*", &Size := 0))
			throw OSError()
		Base64 := Buffer(Size << 1, 0)
		if !(DllCall("crypt32\CryptBinaryToStringW", "Ptr", Binary, "UInt", Binary.Size - 1, "UInt", (CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF), "Ptr", Base64, "UInt*", Size))
			throw OSError()
		return StrGet(Base64)
	}

	/**
	 * Base64解码
	 * https://docs.microsoft.com/zh-cn/windows/win32/api/wincrypt/nf-wincrypt-cryptstringtobinarya
	 * @param VarIn Variable containing a null-terminated Base64 encoded string
	 * @param Codec CRYPT_STRING_BASE64 0x00000001
	 * @returns buffer if success, otherwise blank.
	 * VarOut may contain any binary contents including NUll bytes.
	 */
	static Decode(Base64) {
		static CRYPT_STRING_BASE64 := 0x00000001

		if !(DllCall("crypt32\CryptStringToBinaryW", "Str", Base64, "UInt", 0, "UInt", CRYPT_STRING_BASE64, "Ptr", 0, "UInt*", &Size := 0, "Ptr", 0, "Ptr", 0))
			throw OSError()
		String := Buffer(Size)
		if !(DllCall("crypt32\CryptStringToBinaryW", "Str", Base64, "UInt", 0, "UInt", CRYPT_STRING_BASE64, "Ptr", String, "UInt*", Size, "Ptr", 0, "Ptr", 0))
			throw OSError()
		return StrGet(String, "UTF-8")
	}
}