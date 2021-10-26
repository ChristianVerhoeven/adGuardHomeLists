<#
.SYNOPSIS
Generates adGuardHome whitelist files

.DESCRIPTION
Generates adGuardHome whitelist files

.PARAMETER Path
Supply path to masterList.json

.PARAMETER Destination
Supply destination path to folder

.EXAMPLE
New-AdGuardHomeList.ps1 -Path '/Path/To/file.json'

.EXAMPLE
New-AdGuardHomeList.ps1 -Path 'C:\Path\To\file.json' -Verbose

.NOTES
Author: Christian Verhoeven
Source: https://github.com/ChristianVerhoeven/adGuardHomeLists
Version: 1.0
#>
[cmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Supply path to masterList.json")]
    $Path,

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Supply destination path to folder")]
    $Destination = 'generatedLists'
)

function Assert-CaDestinationPath {
    <#
    .SYNOPSIS
    Asserts the folder where list files will be created
    
    .DESCRIPTION
    Asserts the folder where list files will be created
    
    .PARAMETER Path
    Supply path to validate
    
    .EXAMPLE
    Assert-CaDestinationPath -Path '/path/to/generatedLists'
    
    .NOTES
    Author: Christian Verhoeven
    Source: https://github.com/ChristianVerhoeven/adGuardHomeLists
    Version: 1.0
    #>
    [cmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Supply path to validate")]
        $Path
    )

    if (Test-Path -Path $Path -PathType Container) {
        Write-Verbose "$Path is valid"
        $return = $Path
    }
    else {
        Write-Warning "$Path does not exist, creating"
        try {
            $createdPath = New-Item -Path $Path -ItemType Directory -Force
            Write-Verbose "$Path created successfully"
            $return = $createdPath.FullName
        }
        catch {
            Write-Error "Error creating $Path" + $_.Exception.Message
        }
    }

    return $return
}

# Determine path separator
If ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.Platform -eq 'Unix') { $separator = '/' }
else { $separator = '\' }

# Check if the folder already exists, if not create it.
if ($Destination -eq 'generatedLists') { $destinationPath = Assert-CaDestinationPath -Path ($PSScriptRoot + $separator + $Destination) }
else { $destinationPath = Assert-CaDestinationPath -Path $Destination }

# Validate json path and get content
if ((Test-Path -Path $Path -PathType Leaf) -and ($Path -like '*.json')) {
    $content = (Get-Content -Path $Path | ConvertFrom-Json)
}
else { Write-Error "$Path either does not exist or is not of type json" }

# Process the rule sets.
foreach ($ruleSet in $content.PSObject.Properties) {

    # Define variables
    $ruleSetObject = New-Object -TypeName PSObject -Property @{
        listName        = $ruleSet.Name
        listDescription = $ruleSet.Value.description
    }
    $rules = $ruleSet.Value.rules
    $ruleDescriptions = @{}

    # Process each rule in a rule set
    foreach ($rule in $rules) {
        
        # Set correct action for rule
        switch ($rule.action) {
            'allow' { $action = '@@' }
            'deny' { $action = '' }
            default { $action = 'invalid' }
        }

        # If a correct action is found
        if ($action -ne 'invalid') {

            $modifiers = $rule.modifiers | ForEach-Object { "`$$_" }
            $ruleLine = "$action||$($rule.url)^$($modifiers -join ',')"

            # Add rule to same rule description hashtable to group in text file
            if ($ruleDescriptions.ContainsKey($rule.description)) {
                $ruleDescriptions.ContainsKey("description one")
                $ruleDescriptions[$rule.description] += $ruleLine
            }
            else {
                $ruleDescriptions += @{ $rule.description = @($ruleLine) }
            }
        }
    }

    # Validate the list file
    $fileName = $ruleSetObject.listName + '.txt'
    [string]$filePath = $destinationPath + $separator + $fileName

    if (Test-Path -Path $filePath -PathType Leaf) {
        Write-Verbose "$filePath already exists, re-creating file..."
        try {
            $null = Remove-Item -Path $filePath -Force
            Write-Verbose "$filePath successfully removed."

            $null = New-Item -Path $filePath -ItemType File -Force
            Write-Verbose "$filePath successfully created."
        }
        catch {
            Write-Error "Something went wrong" + $_.Exception.Message
        }
    } else {
        Write-Verbose "$filePath does not exist yet, creating..."
        try {
            $null = New-Item -Path $filePath -ItemType File -Force
            Write-Verbose "$filePath successfully created."
        }
        catch {
            Write-Error "Something went wrong" + $_.Exception.Message
        }
    }

    # Creating TimeZone object
    $timeZone = (Get-TimeZone).DisplayName
    $indexOf = $timeZone.IndexOf(' ')
    $timeZone = $timeZone.Substring(0, $indexOf)

    # Adding content to file
    Add-Content -Path $filePath -Value ("# " + $ruleSetObject.listDescription)
    Add-Content -Path $filePath -Value ("# Time generated: " + (Get-Date -Format "dd-MM-yyyy HH:mm:ss") + " $timeZone" )
    Add-Content -Path $filePath -Value "# Source: https://github.com/ChristianVerhoeven/adGuardHomeLists"
    Add-Content -Path $filePath -Value ""

    # Foreach rule with the same description add the line
    $ruleDescriptions | ForEach-Object {
        Add-Content -Path $filePath -Value ("# " + $_.Keys)

        foreach ($value in $_.Values) {
            Add-Content -Path $filePath -Value $value
        }

        Add-Content -Path $filePath -Value ""
    }

}