param(
  [Parameter(Mandatory = $true)]
  [string]$ApiUrl,

  [Parameter(Mandatory = $true)]
  [string]$ApiToken,

  [string]$SampleProduct = '730-0863'
)

$ErrorActionPreference = 'Stop'

function Join-ApiPath {
  param(
    [Parameter(Mandatory = $true)][string]$Base,
    [Parameter(Mandatory = $true)][string]$Path
  )

  return $Base.TrimEnd('/') + '/' + $Path.TrimStart('/')
}

function Invoke-Json {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [hashtable]$Headers = @{}
  )

  return Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers -TimeoutSec 15
}

$headers = @{ 'X-VettiFlow-Token' = $ApiToken }

Write-Host "1/4 Health da API..."
$health = Invoke-Json -Uri (Join-ApiPath $ApiUrl '/api/v1/health')
Write-Host ("OK: banco={0}; aplicando={1}; empresa={2}" -f $health.banco, $health.aplicando, $health.empresa)

Write-Host "2/4 Rota protegida sem token deve recusar..."
try {
  Invoke-Json -Uri (Join-ApiPath $ApiUrl '/api/v1/produtos?query=730&limit=1') | Out-Null
  throw 'A API aceitou rota protegida sem token.'
} catch {
  $status = $_.Exception.Response.StatusCode.value__
  if ($status -ne 401) {
    throw "Esperado HTTP 401 sem token, recebido HTTP $status."
  }
  Write-Host 'OK: sem token recebeu HTTP 401.'
}

Write-Host "3/4 Busca autenticada de produto..."
$product = Invoke-Json -Uri (Join-ApiPath $ApiUrl "/api/v1/produtos/$SampleProduct") -Headers $headers
if (-not $product.product.code) {
  throw "Produto $SampleProduct nao voltou no formato esperado."
}
Write-Host ("OK: {0} - {1}" -f $product.product.code, $product.product.description)

Write-Host "4/4 Saldos autenticados..."
$balances = Invoke-Json -Uri (Join-ApiPath $ApiUrl "/api/v1/produtos/$SampleProduct/saldos") -Headers $headers
Write-Host ("OK: {0} saldo(s) retornado(s)." -f @($balances).Count)

Write-Host 'Smoke da API concluido. Ainda nao houve escrita em SC2/SD4/SB2.'
