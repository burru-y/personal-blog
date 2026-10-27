# 发布个人博客
#
#   .\deploy.ps1
#
# 与团队博客的部署脚本无关：这里只上传本项目的 dist 到 /opt/personal-blog，
# 然后重建本项目自己的 nginx 容器。不会碰团队站的任何容器或配置。
param(
  [string]$ServerHost = "47.111.71.156",
  [string]$KeyPath = "$env:USERPROFILE\.ssh\_yuxiao.pem",
  [string]$RemoteDir = "/opt/personal-blog"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

Write-Host "`n== 1/5 构建 ==" -ForegroundColor Cyan
Push-Location $root
try {
  & pnpm build | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "构建失败" }
}
finally { Pop-Location }

if (-not (Test-Path (Join-Path $root "dist\index.html"))) {
  throw "构建产物里没有 index.html"
}

Write-Host "`n== 2/5 打包 ==" -ForegroundColor Cyan
$zip = Join-Path $env:TEMP "personal-blog-dist.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
& tar.exe -a -c -f $zip -C (Join-Path $root "dist") . | Out-Null
"包大小 {0:N1} KB" -f ((Get-Item $zip).Length / 1KB)

Write-Host "`n== 3/5 上传 ==" -ForegroundColor Cyan
# 首次部署时需要目录存在
& ssh -i $KeyPath -o StrictHostKeyChecking=no root@$ServerHost "mkdir -p $RemoteDir/dist"
& scp -i $KeyPath -o StrictHostKeyChecking=no $zip "root@${ServerHost}:/root/personal-blog-dist.zip"
& scp -i $KeyPath -o StrictHostKeyChecking=no (Join-Path $root "compose.yaml") "root@${ServerHost}:$RemoteDir/compose.yaml"
& scp -i $KeyPath -o StrictHostKeyChecking=no (Join-Path $root "nginx.conf") "root@${ServerHost}:$RemoteDir/nginx.conf"
if ($LASTEXITCODE -ne 0) { throw "上传失败" }

Write-Host "`n== 4/5 解压并重建容器 ==" -ForegroundColor Cyan
& ssh -i $KeyPath -o StrictHostKeyChecking=no root@$ServerHost `
  "cd $RemoteDir && rm -rf dist/* && unzip -oq /root/personal-blog-dist.zip -d dist && docker compose up -d 2>&1 | tail -n 3"
if ($LASTEXITCODE -ne 0) { throw "部署失败" }

Write-Host "`n== 5/5 验证 ==" -ForegroundColor Cyan
& ssh -i $KeyPath -o StrictHostKeyChecking=no root@$ServerHost `
  "curl -s -o /dev/null -w '首页 %{http_code}\n' http://127.0.0.1:8081/ && curl -s -o /dev/null -w '归档 %{http_code}\n' http://127.0.0.1:8081/archive/"
if ($LASTEXITCODE -ne 0) { throw "验证失败" }

Write-Host "`n已发布：http://${ServerHost}:8081/" -ForegroundColor Green
