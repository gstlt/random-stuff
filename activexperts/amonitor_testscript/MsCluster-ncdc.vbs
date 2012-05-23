' ///////////////////////////////////////////////////////////////////////////////
' // ActiveXperts Network Monitor  - VBScript based checks
' // © 1999-2006, ActiveXperts Software B.V.
' //
' // For more information about ActiveXperts Network Monitor and VBScript, please
' // visit the online ActiveXperts Network Monitor VBScript Guidelines at:
' //    http://www.activexperts.com/support/activmonitor/online/vbscript/
' // 
' ///////////////////////////////////////////////////////////////////////////////
'  /

Option Explicit
Const  retvalUnknown = 1
Dim    SYSDATA, SYSEXPLANATION  ' Used by Network Monitor, don't change the names


' ///////////////////////////////////////////////////////////////////////////////
' // To test a function outside Network Monitor (e.g. using CSCRIPT from the
' // command line), remove the comment character (') in the following 5 lines:
' Dim bResult
' bResult =  CheckCluster( "cluster-server-name", "service-name")
' WScript.Echo "Return value: [" & bResult & "]"
' WScript.Echo "SYSDATA: [" & SYSDATA & "]"
' WScript.Echo "SYSEXPLANATION: [" & SYSEXPLANATION & "]"
' //////////////////////////////////////////////////////////////////////////////


' //////////////////////////////////////////////////////////////////////////////

Function CheckCluster( strComputer, strGroup )

' Description: 
'     Checks if specified cluster group runs on specified node.
' Parameters:
'     1) strComputer As String - Hostname or IP address of the cluster node you want to check
'     2) strCredentials As String - Specify an empty string to use Network Monitor service credentials.
'         To use alternate credentials, enter a server that is defined in Server Credentials table.
'         (To define Server Credentials, choose Tools->Options->Server Credentials)
' Usage:
'     CheckCluster( "<String Nodename>", "<String Group Name>" )
' Sample:
'     CheckExchange( "localhost", "ExampleGroup" )

    Dim objWMIService, numResult

    CheckCluster      = retvalUnknown  ' Default return value
    SYSDATA            = ""             ' Not used by this function
    SYSEXPLANATION     = "Couldn't check cluster!"             ' Set initial value

Dim colItems, objItem

'On Error Resume Next

' TODO: Use Network Monitor windows crfedentials to check other computers.
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\.\root\mscluster")

Set colItems = objWMIService.ExecQuery("select PartComponent, GroupComponent from MSCluster_NodeToActiveGroup where __RELPATH like '%" & _
        strComputer & "%' and __RELPATH like '%" & strGroup & "%'")

If colItems.Count<>1 Then

	CheckCluster = False
	SYSEXPLANATION = "Cluster group " & strGroup & " isnt running on proper node!"
	Exit Function

Else

	CheckCluster = True
	SYSEXPLANATION = "Cluster group " & strGroup & " is running on " & strComputer
	Exit Function
End If

    
End Function
