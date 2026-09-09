#Requires -Version 7.0
param(
    [string]$BuildTools,
    [string]$AndroidJar,
    [string]$R8Jar,
    [string]$JavaHome=$env:JAVA_HOME,
    [string]$KeyStore,
    [string]$OutputDirectory=(Join-Path $PSScriptRoot '..\Build'),
    [string]$KeyAlias='thor-local'
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if(-not $BuildTools){$BuildTools=Join-Path $projectRoot 'tools\android-build\android-14'}
if(-not $AndroidJar){$AndroidJar=Join-Path $projectRoot 'tools\android-platform\android-33-ext5\android.jar'}
if(-not $R8Jar){$R8Jar=Join-Path $projectRoot 'tools\r8.jar'}
if(-not $JavaHome){$JavaHome=Split-Path (Split-Path (Get-Command javac.exe -ErrorAction Stop).Source)}
foreach($required in @("$BuildTools\aapt.exe","$BuildTools\zipalign.exe","$BuildTools\apksigner.bat",$AndroidJar,$R8Jar,"$JavaHome\bin\javac.exe")){
    if(-not(Test-Path -LiteralPath $required)){throw "Outil manquant : $required. Fournir les parametres SDK/JDK indiques dans README.md."}
}
$env:JAVA_HOME=$JavaHome
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $OutputDirectory,"$OutputDirectory\classes","$OutputDirectory\dex" | Out-Null
function Check([string]$Step){if($LASTEXITCODE -ne 0){throw "$Step a echoue ($LASTEXITCODE)"}}
$javaFiles=@(Get-ChildItem -LiteralPath "$PSScriptRoot\java" -Recurse -Filter '*.java' | ForEach-Object FullName)
& "$JavaHome\bin\javac.exe" --release 8 -encoding UTF-8 -cp $AndroidJar -d "$OutputDirectory\classes" @javaFiles
Check 'Compilation Java'
$classFiles=@(Get-ChildItem -LiteralPath "$OutputDirectory\classes" -Recurse -Filter '*.class' | ForEach-Object FullName)
& "$JavaHome\bin\java.exe" -cp $R8Jar com.android.tools.r8.D8 --min-api 26 --lib $AndroidJar --output "$OutputDirectory\dex" @classFiles
Check 'Compilation DEX'
& "$BuildTools\aapt.exe" package -f -M "$PSScriptRoot\AndroidManifest.xml" -I $AndroidJar -S "$PSScriptRoot\res" -A "$PSScriptRoot\assets" -F "$OutputDirectory\unsigned.apk"
Check 'Paquet APK'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::Open("$OutputDirectory\unsigned.apk",[IO.Compression.ZipArchiveMode]::Update)
try{[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,"$OutputDirectory\dex\classes.dex",'classes.dex') | Out-Null}finally{$zip.Dispose()}
& "$BuildTools\zipalign.exe" -f 4 "$OutputDirectory\unsigned.apk" "$OutputDirectory\aligned.apk"
Check 'Alignement APK'
if(-not $KeyStore){
    $KeyStore=Join-Path $OutputDirectory 'local-signing.jks'
    if(-not(Test-Path -LiteralPath $KeyStore)){
        & "$JavaHome\bin\keytool.exe" -genkeypair -keystore $KeyStore -alias $KeyAlias -storepass changeit -keypass changeit -dname 'CN=Thor WiFi Local Build' -keyalg RSA -keysize 2048 -validity 10000
        Check 'Creation de cle locale'
    }
}
# Local sideload signature. Keep the keystore private and reuse it for updates.
& "$BuildTools\apksigner.bat" sign --ks $KeyStore --ks-key-alias $KeyAlias --ks-pass pass:changeit --key-pass pass:changeit --out "$OutputDirectory\Thor-WiFi.apk" "$OutputDirectory\aligned.apk"
Check 'Signature APK'
& "$BuildTools\apksigner.bat" verify --verbose "$OutputDirectory\Thor-WiFi.apk"
Check 'Verification signature'
Get-FileHash -LiteralPath "$OutputDirectory\Thor-WiFi.apk" -Algorithm SHA256
