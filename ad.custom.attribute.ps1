Param
(
    	[string]$user='Administrator',
    	[string]$ADproperties='SID'
)

Get-aduser $user -properties "$ADproperties" | select SamAccountName,@{name='$ADproperties';e={$_.$ADproperties}}
