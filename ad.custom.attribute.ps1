Get-aduser $user -properties "<customADpropertyName>" | select SamAccountName,@{name='<customADpropertyName>';e={$_.<customADpropertyName>}}
