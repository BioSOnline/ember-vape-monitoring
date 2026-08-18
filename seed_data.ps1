# Load .env file if present
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line.Split("=", 2)
            if ($parts.Length -eq 2) {
                [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
            }
        }
    }
}

$SUPABASE_URL = [Environment]::GetEnvironmentVariable("SUPABASE_URL")
$ANON_KEY = [Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY")
$SEED_EMAIL = [Environment]::GetEnvironmentVariable("SEED_USER_EMAIL")
if (-not $SEED_EMAIL) { $SEED_EMAIL = "test@example.com" }
$SEED_PASSWORD = [Environment]::GetEnvironmentVariable("SEED_USER_PASSWORD")
if (-not $SEED_PASSWORD) { $SEED_PASSWORD = "testpassword123" }

if (-not $SUPABASE_URL -or -not $ANON_KEY) {
    Write-Host "Missing SUPABASE_URL or SUPABASE_ANON_KEY in environment or .env file." -ForegroundColor Red
    exit 1
}

# --- Step 1: Sign in seed user ---
Write-Host "Signing in as $SEED_EMAIL..." -ForegroundColor Cyan
$loginBody = @{ email = $SEED_EMAIL; password = $SEED_PASSWORD } | ConvertTo-Json
$loginRes = Invoke-RestMethod -Uri "$SUPABASE_URL/auth/v1/token?grant_type=password" `
    -Method POST -ContentType "application/json" `
    -Headers @{ apikey = $ANON_KEY } -Body $loginBody

$TOKEN = $loginRes.access_token
$USER_ID = $loginRes.user.id

if (-not $TOKEN) {
    Write-Host "Login FAILED. Check email/password." -ForegroundColor Red
    exit 1
}
Write-Host "Signed in! User ID: $USER_ID" -ForegroundColor Green

# Common headers for all subsequent requests
$headers = @{
    apikey        = $ANON_KEY
    Authorization = "Bearer $TOKEN"
    "Content-Type" = "application/json"
    Prefer        = "return=minimal"
}

# --- Step 2: Generate 7 days of data ---
$now = Get-Date
$totalPuffs = 0
$totalSessions = 0
$rand = New-Object System.Random(42)

for ($daysAgo = 6; $daysAgo -ge 0; $daysAgo--) {
    $day = ($now.Date).AddDays(-$daysAgo)
    $dayLabel = $day.ToString("yyyy-MM-dd")

    # Random 1-3 sessions per day
    $sessionCount = 1 + $rand.Next(3)
    # Random 8-22 puffs per day
    $dailyPuffs = 8 + $rand.Next(15)

    Write-Host "`nDay $dayLabel : $dailyPuffs puffs, $sessionCount sessions" -ForegroundColor Yellow

    # Distribute puffs across sessions
    $puffsPerSession = @()
    $base = [Math]::Floor($dailyPuffs / $sessionCount)
    $remainder = $dailyPuffs % $sessionCount
    for ($i = 0; $i -lt $sessionCount; $i++) {
        if ($i -eq 0) { $puffsPerSession += ($base + $remainder) } else { $puffsPerSession += $base }
    }

    for ($s = 0; $s -lt $sessionCount; $s++) {
        $sessionId = [guid]::NewGuid().ToString()
        $startHour = 7 + [Math]::Floor((16 * $s) / $sessionCount) + $rand.Next(2)
        $startMin = $rand.Next(60)
        $sessionStart = $day.AddHours($startHour).AddMinutes($startMin)

        $puffsInSession = $puffsPerSession[$s]
        $avgInterval = 30.0 + $rand.NextDouble() * 180.0
        $durationMin = [Math]::Max(2, [Math]::Min(60, [Math]::Round($puffsInSession * $avgInterval / 60)))
        $sessionEnd = $sessionStart.AddMinutes($durationMin)

        # Insert session
        $sessionBody = @{
            id = $sessionId
            user_id = $USER_ID
            started_at = $sessionStart.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            ended_at = $sessionEnd.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            puff_count = $puffsInSession
            avg_interval_sec = [Math]::Round($avgInterval, 1)
        } | ConvertTo-Json

        Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/sessions" `
            -Method POST -Headers $headers -Body $sessionBody | Out-Null

        Write-Host "   Session $($s+1): $puffsInSession puffs, ${durationMin}min ($($sessionStart.ToString('HH:mm'))-$($sessionEnd.ToString('HH:mm')))" -ForegroundColor DarkGray

        # Insert puff events
        for ($p = 0; $p -lt $puffsInSession; $p++) {
            $offsetSec = [Math]::Round($p * $avgInterval) + $rand.Next(20)
            $puffTime = $sessionStart.AddSeconds($offsetSec)

            $modeRoll = $rand.NextDouble()
            if ($modeRoll -lt 0.55) { $inputMode = "manual" }
            elseif ($modeRoll -lt 0.80) { $inputMode = "video_upload" }
            else { $inputMode = "live_camera" }

            $confScore = $null
            if ($inputMode -ne "manual") {
                $confScore = [Math]::Round(0.55 + $rand.NextDouble() * 0.43, 3)
            }

            $puffBody = @{
                id = [guid]::NewGuid().ToString()
                user_id = $USER_ID
                session_id = $sessionId
                detected_at = $puffTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                input_mode = $inputMode
            }
            if ($null -ne $confScore) { $puffBody.confidence_score = $confScore }
            $puffJson = $puffBody | ConvertTo-Json

            Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/puff_events" `
                -Method POST -Headers $headers -Body $puffJson | Out-Null
        }

        $totalPuffs += $puffsInSession
        $totalSessions++
    }
}

# --- Step 3: Insert addiction score ---
$dailyAvg = $totalPuffs / 7.0

if ($dailyAvg -gt 20) {
    $level = "high"; $scoreVal = 70 + $rand.Next(25); $topFeature = "High daily puff count"
} elseif ($dailyAvg -gt 10) {
    $level = "moderate"; $scoreVal = 40 + $rand.Next(25); $topFeature = "Frequent short-interval sessions"
} else {
    $level = "low"; $scoreVal = 10 + $rand.Next(25); $topFeature = "Low usage volume"
}

$scoreBody = @{
    id = [guid]::NewGuid().ToString()
    user_id = $USER_ID
    scored_at = $now.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    level = $level
    score_value = $scoreVal
    top_feature = $topFeature
} | ConvertTo-Json

Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/addiction_scores" `
    -Method POST -Headers $headers -Body $scoreBody | Out-Null

Write-Host "`n====================================" -ForegroundColor Green
Write-Host "SEED COMPLETE" -ForegroundColor Green
Write-Host "   $totalPuffs puff events across $totalSessions sessions (7 days)" -ForegroundColor White
Write-Host "   Daily avg: $([Math]::Round($dailyAvg, 1)) puffs/day" -ForegroundColor White
Write-Host "   Addiction: $level ($scoreVal/100) - $topFeature" -ForegroundColor White
Write-Host "====================================" -ForegroundColor Green
