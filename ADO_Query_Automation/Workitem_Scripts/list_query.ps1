param(
    [string]$organization,
    [string]$pat,
    [string]$startDate,
    [string]$endDate,
    [string]$tags,
    [string]$projectList
)

# Auth header
$base64AuthInfo = [Convert]::ToBase64String(
    [Text.Encoding]::ASCII.GetBytes(":$pat")
)

$headers = @{
    Authorization  = "Basic $base64AuthInfo"
    "Content-Type" = "application/json"
}

Write-Host "Tags: $tags"

# Split projects
$projects   = $projectList -split ","
$mergedData = @()

foreach ($project in $projects)
{
    $project = $project.Trim()

    if ([string]::IsNullOrWhiteSpace($project)) {
        continue
    }

    Write-Host "========================================="
    Write-Host "Processing project: $project"

    $areaPath = $project

    # Output file (local vs pipeline)
    if ($env:BUILD_ARTIFACTSTAGINGDIRECTORY) {
        $outputFile = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY\$project.csv"
    }
    else {
        $outputFile = "$project.csv"
    }

    # Tag filter
    $tagArray = $tags -split "," | ForEach-Object { $_.Trim() }

    $tagFilter = ($tagArray | ForEach-Object {
        "[System.Tags] CONTAINS '$_'"
    }) -join " OR "

    $tagFilter = "($tagFilter)"

    # WIQL query
    $wiql = @"
SELECT
    [System.Id],
    [System.Title],
    [System.State],
    [System.AssignedTo],
    [System.WorkItemType],
    [System.Tags],
    [Microsoft.VSTS.Scheduling.CompletedWork],
    [Microsoft.VSTS.Scheduling.RemainingWork],
    [Microsoft.VSTS.Scheduling.OriginalEstimate],
    [Microsoft.VSTS.Scheduling.Effort],
    [Microsoft.VSTS.Common.ClosedDate]
FROM WorkItems
WHERE
    [System.TeamProject] = '$project'
    AND [System.WorkItemType] IN ('Bug','Task','Product Backlog Item')
    AND [System.AreaPath] UNDER '$areaPath'
    AND [System.State] = 'Done'
    AND [Microsoft.VSTS.Common.ClosedDate] >= '$startDate'
    AND [Microsoft.VSTS.Common.ClosedDate] <= '$endDate'
    AND $tagFilter
ORDER BY [System.CreatedDate] DESC
"@

    $body = @{
        query = $wiql
    } | ConvertTo-Json

    $wiqlUrl = "https://dev.azure.com/$organization/$project/_apis/wit/wiql?api-version=7.0"

    # Execute WIQL
    try {
        $response = Invoke-RestMethod `
            -Uri $wiqlUrl `
            -Method Post `
            -Headers $headers `
            -Body $body
    }
    catch {
        Write-Host "WIQL failed for $project"
        Write-Host $_
        continue
    }

    if (-not $response.workItems -or $response.workItems.Count -eq 0) {
        Write-Host "No work items found for $project"
        continue
    }

    $ids = @($response.workItems | ForEach-Object { $_.id })
    Write-Host "Work items found: $($ids.Count)"

    # Fetch work item details in batches
    $batchSize   = 200
    $allWorkItems = @()

    for ($i = 0; $i -lt $ids.Count; $i += $batchSize)
    {
        $end      = [math]::Min($i + $batchSize - 1, $ids.Count - 1)
        $batchIds = $ids[$i..$end] -join ","

        if (-not $batchIds) {
            continue
        }

        $workItemUrl = "https://dev.azure.com/$organization/$project/_apis/wit/workitems?ids=$batchIds&`$expand=relations&api-version=7.0"

        try {
            $result = Invoke-RestMethod `
                -Uri $workItemUrl `
                -Headers $headers `
                -Method Get

            if ($result.value) {
                $allWorkItems += $result.value
            }
        }
        catch {
            Write-Host "Error fetching batch"
            Write-Host $_
        }
    }

    # Lookup: ID → Title
    $workItemLookup = @{}
    $allWorkItems | ForEach-Object {
        $workItemLookup[$_.id] = $_.fields.'System.Title'
    }

    Write-Host "Total fetched work items: $($allWorkItems.Count)"

    # Convert to CSV format
    $data = $allWorkItems | ForEach-Object {

        $areaPath     = $_.fields.'System.AreaPath'
        $rootProject  = ($areaPath -split "\\")[0]

        $parentId = ""

        if ($_.relations -ne $null) {
            $parentRelation = $_.relations | Where-Object {
                $_.rel -like "*Hierarchy-Reverse"
            } | Select-Object -First 1

            if ($parentRelation) {
                $parentId = ($parentRelation.url -split "/")[-1]
            }
        }

        [PSCustomObject]@{
            ProjectName      = $project
            ID               = $_.id
            Title            = $_.fields.'System.Title'
            State            = $_.fields.'System.State'
            ParentID         = $parentId
            WorkItemType     = $_.fields.'System.WorkItemType'
            Tags             = $_.fields.'System.Tags'
            AssignedTo       = if ($_.fields.'System.AssignedTo') { $_.fields.'System.AssignedTo'.displayName } else { "" }
            Efforts          = $_.fields.'Microsoft.VSTS.Scheduling.Effort'
            CompletedWork    = $_.fields.'Microsoft.VSTS.Scheduling.CompletedWork'
            RemainingWork    = $_.fields.'Microsoft.VSTS.Scheduling.RemainingWork'
            OriginalEstimate = $_.fields.'Microsoft.VSTS.Scheduling.OriginalEstimate'
            ClosedDate       = $_.fields.'Microsoft.VSTS.Common.ClosedDate'
            AreaPath         = $_.fields.'System.AreaPath'
        }
    }

    Write-Host "Items ready for export: $($data.Count)"

    if ($data.Count -eq 0) {
        Write-Host "No data to export for $project"
        continue
    }

    # Export project CSV
    $data | Export-Csv $outputFile -NoTypeInformation
    $mergedData += $data

    Write-Host "CSV exported"
}

# Export merged CSV
if ($mergedData.Count -gt 0)
{
    if ($env:BUILD_ARTIFACTSTAGINGDIRECTORY) {
        $mergedOutputFile = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY\AllProjects_Merged.csv"
    }
    else {
        $mergedOutputFile = "AllProjects_Merged.csv"
    }

    $mergedData | Export-Csv $mergedOutputFile -NoTypeInformation
    Write-Host "Merged CSV exported: $mergedOutputFile"
}
else {
    Write-Host "No data available to generate merged CSV"
}

Write-Host "========================================="
Write-Host "Script completed"