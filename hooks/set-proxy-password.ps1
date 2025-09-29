param()
if (-not $env:PROXY_AUTH_PASSWORD) {
  $secure = Read-Host -Prompt "Enter nginx proxy password" -AsSecureString
  $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    try {
      azd env set PROXY_AUTH_PASSWORD $plain --secret | Out-Null
    }
    catch {
      azd env set PROXY_AUTH_PASSWORD $plain | Out-Null
    }
    $env:PROXY_AUTH_PASSWORD = $plain
  }
  finally {
    if ($bstr -ne [System.IntPtr]::Zero) {
      [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
  }
}