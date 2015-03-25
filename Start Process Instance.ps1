Add-Type -AssemblyName ('SourceCode.Workflow.Client, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d')
$k2con = New-Object -TypeName SourceCode.Workflow.Client.Connection
$k2con.Open("localhost")
$k2con.ImpersonateUser("K2SQL:somebody@bla.com");
$proc = $k2con.CreateProcessInstance("TestingWorkflows\AdvancedDestination");
$proc.DataFields["Data.RequestId"].Value = "1";
$proc.Folio = "The folio";
$k2con.StartProcessInstance($proc);
$k2con.close()
