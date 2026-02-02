 = \ F:\Game\WOW Turtle\twmoa_1180 — копия\WTF\Account\LOGOSHH\SavedVariables\
 = Get-ChildItem -Path  -Filter \SOTA.lua\ -ErrorAction SilentlyContinue
if () {
    Remove-Item -Path .FullName -Force
    Write-Host \SavedVariables file deleted successfully!\
    exit 0
} else {
    Write-Host \SavedVariables file not found\
    exit 1
}