function New-JevProbabilityDistribution {
    <# Builds a valid probability distribution for a mock Choice or Score. #>
    param(
        [Parameter(Mandatory)]
        [string[]] $Keys,

        [Parameter(Mandatory)]
        [int] $SelectedIndex
    )

    $distribution = [ordered] @{}
    if ($Keys.Count -eq 1) {
        $distribution[$Keys[0]] = 1.0
        return $distribution
    }

    $selectedProbability = 0.82
    $otherProbability = (1.0 - $selectedProbability) / ($Keys.Count - 1)

    for ($index = 0; $index -lt $Keys.Count; $index++) {
        $distribution[$Keys[$index]] = if ($index -eq $SelectedIndex) {
            [math]::Round($selectedProbability, 4)
        }
        else {
            [math]::Round($otherProbability, 4)
        }
    }

    return $distribution
}
