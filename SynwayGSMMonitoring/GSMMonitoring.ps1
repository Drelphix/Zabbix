# Проверяем, переданы ли все необходимые параметры
param (
    [string]$GatewayIP,
    [string]$Username,
    [string]$Password
)

if (-not $GatewayIP -or -not $Username -or -not $Password) {
    Write-Host "Ошибка: необходимо передать IP шлюза, логин и пароль."
    exit 1
}

# Указываем путь к WebDriver.Support.dll
Add-Type -Path "C:\GSMMonitoring\driver\WebDriver.Support.dll"

# Пути к Chrome и ChromeDriver
$chromeBinaryPath = "C:\GSMMonitoring\chrome\chrome-win64\chrome.exe"
$chromeDriverPath = "C:\GSMMonitoring\driver"

# Создаем объект для настроек Chrome
$options = New-Object OpenQA.Selenium.Chrome.ChromeOptions
$options.BinaryLocation = $chromeBinaryPath  # Указываем путь к Chrome.exe
$options.AddArgument("--no-sandbox")
$options.AddArgument("--disable-dev-shm-usage")

# Указываем полный путь к ChromeDriver
$chromeDriverService = [OpenQA.Selenium.Chrome.ChromeDriverService]::CreateDefaultService($chromeDriverPath)

# Создаем драйвер с явным указанием сервиса и опций
$driver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($chromeDriverService, $options)

# Устанавливаем явное ожидание
$wait = New-Object OpenQA.Selenium.Support.UI.WebDriverWait($driver, [TimeSpan]::FromSeconds(5))

$results = @()

# Формируем URL с учетными данными
$url = "http://$($Username):$($Password)@$GatewayIP/en/1-2chstatus.php"

# Переходим на страницу шлюза
$driver.Navigate().GoToUrl($url)
Start-Sleep -Seconds 2 # Пауза для загрузки страницы

# Получаем все строки таблицы
$rows = $driver.FindElementsByCssSelector("table.wid1 tbody tr")

# Проходим по строкам таблицы
foreach ($row in $rows) {
    # Попробуем найти ячейку с портом
    $portElement = $row.FindElementByCssSelector("td:first-child")
    
    # Если порт найден, продолжаем обработку
    if ($portElement -ne $null) {
        $port = $portElement.Text

        # Пропускаем строку, если она пустая
        if (![string]::IsNullOrEmpty($port)) {
            # Динамические селекторы для каждого порта
            $sipStatus = $row.FindElementByCssSelector("td#SIP_RegStatus$($port - 1)").Text
            $state = $row.FindElementByCssSelector("td#channe$($port - 1)").Text
            $connection = $row.FindElementByCssSelector("td#GSM_RegStatus$($port - 1)").Text
            

            # Добавляем результаты в массив
            $results += [PSCustomObject]@{
                Port        = $port
                SIPStatus   = $sipStatus
                State       = $state
                Connection  = $connection
            }
        }
    }
}

# Закрываем браузер
$driver.Quit()

# Выводим результаты в формате JSON
@{ data = $results } | ConvertTo-Json -Depth 3
