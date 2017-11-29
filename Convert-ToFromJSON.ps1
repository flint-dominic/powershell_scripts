$text = @'
{
    "sync_promo": {
        "startup_count": 1
    }
}
'@

$obj = $text | ConvertFrom-Json
$obj.sync_promo | Add-Member -MemberType NoteProperty -Name user_skipped -Value $true
$obj | ConvertTo-Json
