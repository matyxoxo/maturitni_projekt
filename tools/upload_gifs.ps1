# Nahrava GIFy datasetu do Supabase Storage.
# Pouziti (PowerShell):
#   $env:SUPABASE_SERVICE_ROLE_KEY = "tvuj-service-role-klic"
#   powershell -File tools\upload_gifs.ps1
#
# Klic najdes v Supabase Dashboard -> Settings -> API -> service_role
# NIKAM ho neukladej do repozitare!

$ErrorActionPreference = 'Stop'

$serviceKey = $env:SUPABASE_SERVICE_ROLE_KEY
if (-not $serviceKey) {
    Write-Error 'Nastav promennou SUPABASE_SERVICE_ROLE_KEY (Supabase -> Settings -> API).'
}

$baseUrl = 'https://ydgofprtqohzhjfwjtqq.supabase.co'
$bucket = 'exercise-gifs'
$videosDir = 'C:\Users\matej\AppData\Local\Temp\opencode\exercises-dataset\videos'

$headers = @{
    'Authorization'  = "Bearer $serviceKey"
    'x-upsert'       = 'true'
}

Write-Host 'Vytvarim bucket exercise-gifs...'
try {
    Invoke-RestMethod -Method Post -Uri "$baseUrl/storage/v1/bucket" `
        -Headers @{ 'Authorization' = "Bearer $serviceKey" } `
        -ContentType 'application/json' `
        -Body (@{ id = $bucket; name = 'Exercise GIFs'; public = $true } | ConvertTo-Json)
    Write-Host 'Bucket vytvoren.'
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 409) {
        Write-Host 'Bucket uz existuje.'
    } else {
        throw
    }
}

$files = Get-ChildItem -Path $videosDir -Filter *.gif
$total = $files.Count
$i = 0
$failed = 0

foreach ($f in $files) {
    $i++
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    try {
        Invoke-RestMethod -Method Post `
            -Uri "$baseUrl/storage/v1/object/$bucket/$($f.Name)" `
            -Headers $headers `
            -ContentType 'image/gif' `
            -Body $bytes | Out-Null
    } catch {
        $failed++
        Write-Warning "CHYBA: $($f.Name) - $($_.Exception.Message)"
    }
    if ($i % 50 -eq 0 -or $i -eq $total) {
        Write-Host "Hotovo $i / $total (chyb: $failed)"
    }
}

Write-Host '=== Konec ==='
Write-Host "Nahrano: $($total - $failed) / $total"
if ($failed -gt 0) { exit 1 }
