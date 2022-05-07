
Function CustomerFormPOST(Request)  
	
	Response = New HTTPServiceResponse(200);     
	
	RequestText = Request.GetBodyAsString();   
	
	WriteLogEvent("Slack.CustomerFormPOST",,, RequestText);   
	
	JSONReader = New JSONReader;   
	JSONReader.SetString(RequestText);   
	
	Try 
		Object = ReadJSON(JSONReader, True);
	Except 		
	 	Return Response; 
	EndTry;
	
	JSONReader.Close();         
	
	DataReader = New DataReader(Base64Value(Object.Get("body")));
	UserRequest = DataReader.ReadLine();
	DataReader.Close();
	
	If StrStartsWith(UserRequest, "payload=") Then    
		
		UserRequest = DecodeString(Mid(UserRequest, 9), StringEncodingMethod.URLEncoding);  
		
		Return PerformUserAction_SaveCustomer(UserRequest);
		
	EndIf;   
	
	// Return New Customer Form ...
	
	UserRequestArray = StrSplit(UserRequest, "&");       
	
	ChannelId = "";	
	ChannelName = "";	
	UserMessage = "";
	UserName = "";
	AccessToken = "";
	Trigger = "";
	
	For Each Value in UserRequestArray Do  
		
		If StrStartsWith(Value, "channel_name=") Then 
			ChannelName = StrReplace(Value, "channel_name=", "");
		ElsIf StrStartsWith(Value, "channel_id=") Then 
			ChannelId = StrReplace(Value, "channel_id=", "");
		ElsIf StrStartsWith(Value, "text=") Then
			UserMessage =  DecodeString(StrReplace(Value, "text=", ""), StringEncodingMethod.URLInURLEncoding); 	
		ElsIf StrStartsWith(Value, "user_name=") Then
			UserName =  StrReplace(Value, "user_name=", ""); 		
		ElsIf StrStartsWith(Value, "token=") Then
			AccessToken =  StrReplace(Value, "token=", ""); 		
		ElsIf StrStartsWith(Value, "trigger_id=") Then
			Trigger =  StrReplace(Value, "trigger_id=", ""); 		
		EndIf;
		
	EndDo;
	
	
	
	//---------------------------------------------
	
	AllBlocks = New Array;    
	
	Element = New Structure("type,text", "plain_text", "Enter new customer details");  
	AllBlocks.Add(New Structure("type,text", "header", Element));
	
	Element = New Structure("type,multiline,action_id", "plain_text_input", false, "plain_text_input_customer_name");    
	Label = New Structure("type,text", "plain_text", "Customer Name");    

	MessageInput = New Structure("type,element,label,block_id", "input", Element, Label, "customer_name"); 	 
	AllBlocks.Add(MessageInput);  
	//---------------------------------------------      
	Element = New Structure("type,multiline,action_id", "plain_text_input", false, "plain_text_input_customer_address");    
	Label = New Structure("type,text", "plain_text", "Customer Address");    

	MessageInput = New Structure("type,element,label,block_id", "input", Element, Label, "customer_address"); 	 
	AllBlocks.Add(MessageInput);     
	
	//---------------------------------------------      
	AllBlocks.Add(New Structure("type", "divider"));        

	//---------------------------------------------
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Managers.Code AS Code,
	|	Managers.Description AS Description,
	|	Managers.CustomerSupportDescription AS CustomerSupportDescription
	|FROM
	|	Catalog.Managers AS Managers"; 
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();   
	
	ManagerElementsOptions = New Array;
	
	While SelectionDetailRecords.Next() Do     
		
		ManagerText = New Structure("type,text", "plain_text", SelectionDetailRecords.Description);   
		
		ManagerId = String(SelectionDetailRecords.Code);  

		ManagerDescription = New Structure("text,value", ManagerText, ManagerId);		
		
		ManagerElementsOptions.Add(ManagerDescription);    
		
		//--------------------------------         
		ManagerDescriptionElement = "*" + SelectionDetailRecords.Description + "* " + SelectionDetailRecords.CustomerSupportDescription;	
		ManagerDescriptionElements = New Array;
		ManagerDescriptionElements.Add( New Structure("type,text", "mrkdwn", ManagerDescriptionElement));
		ManagerContext = New Structure("type,elements", "context", ManagerDescriptionElements);	
		
		AllBlocks.Add(ManagerContext);
		
	EndDo;   
	
	ManagerElements =  New Structure("type,placeholder,action_id,options", 
		"multi_static_select", 
		New Structure("type,text", "plain_text", "Select all managers"),
		"multi_static_select_managers",
		ManagerElementsOptions);
	
	Managers = New Structure("type,element,label,block_id", 
		"input", 
		ManagerElements, 
		New Structure("type,text", "plain_text", "All avaliable managers"),
		"all_managers");
	
	AllBlocks.Add(Managers); 

	//-----------------------------------------------------   
	
	SlackResponse = New Structure("blocks", AllBlocks);   
	SlackResponse.Insert("title", New Structure("type,text", "plain_text", "Adding New Customer"));	  
	SlackResponse.Insert("submit", New Structure("type,text", "plain_text", "Save to 1C"));	  
	SlackResponse.Insert("type", "modal");	  
	SlackResponse.Insert("callback_id", "modal-identifier");    
	
	//-----------------------------------------------------    
	
	SlackResponse = New Structure("trigger_id,view", Trigger, SlackResponse);  
	
	//-----------------------------------------------------   
	
	JSONWriter = New JSONWriter; 
	JSONWriter.SetString();
	WriteJSON(JSONWriter, SlackResponse);
	Result = JSONWriter.Close();	
	//
	//-----------------------------------------------------  
	AccessToken = Constants.AccessToken.Get();
	NewPostRequest = New HTTPRequest("/api/views.open");  
	NewPostRequest.Headers.Insert("Content-type", "application/json");
	NewPostRequest.Headers.Insert("Authorization", "Bearer " + AccessToken);     
	NewPostRequest.SetBodyFromString(Result);
	
	Client = new HTTPConnection("slack.com", 443, , , , , new OpenSSLSecureConnection);
	ResultRequest = Client.Post(NewPostRequest);  
	
	//Str = ResultRequest.GetBodyAsString();
	
	//-----------------------------------------------------
	
	Response = New HTTPServiceResponse(200);     
	Response.SetBodyFromString("");
	Return Response;     
	

	
EndFunction        


Function PerformUserAction_SaveCustomer(Payload)   
	
	Response = New HTTPServiceResponse(200);   
	Response.SetBodyFromString("");
	
	JSONReader = New JSONReader;   
	JSONReader.SetString(Payload);   
	
	CustomerName = "";
	CustomerAddress = "";
	Managers = New Array;      
	
	Try 
		Object = ReadJSON(JSONReader);	
		
		CustomerName = Object.view.state.values.customer_name.plain_text_input_customer_name.value; 
		CustomerAddress = Object.view.state.values.customer_address.plain_text_input_customer_address.value;  
		
		CustomerName = StrReplace(CustomerName, "+", " ");
		CustomerAddress = StrReplace(CustomerAddress, "+", " ");
		
		For Each ManagerCode in Object.view.state.values.all_managers.multi_static_select_managers.selected_options Do    
			
			Manager = Catalogs.Managers.FindByCode(ManagerCode.value); 
			
			If Not Manager.IsEmpty() Then    
				Managers.Add(Manager);
			EndIf;  
			
		EndDo; 
		
	Except 		
	 	Return Response; 
	EndTry;      
	
	NewCustomer = Catalogs.Customers.CreateItem();
	NewCustomer.Description = CustomerName;
	NewCustomer.Address = CustomerAddress;
	
	SlackResponse = "I've created a new customer '" + CustomerName + "' with these managers: ";
	
	For Each Manager in Managers Do        
		
		SlackResponse = SlackResponse + ", " + Manager;	     
		
		Row = NewCustomer.Managers.Add();
		Row.DedicatedManager = Manager;
		
	EndDo; 
	
	NewCustomer.Write();
	
	
	Result = New Structure("channel,text", Constants.ChannelId.Get(), SlackResponse);     
	
	JSONWriter = New JSONWriter; 
	JSONWriter.SetString();
	WriteJSON(JSONWriter, Result);
	ResultJson = JSONWriter.Close();	

	Try  
		
		AccessToken = Constants.AccessToken.Get();
		NewPostRequest = New HTTPRequest("/api/chat.postMessage");  
		NewPostRequest.Headers.Insert("Content-type", "application/json");
		NewPostRequest.Headers.Insert("Authorization", "Bearer " + AccessToken);     
		NewPostRequest.SetBodyFromString(ResultJson);
		
		Client = new HTTPConnection("slack.com", 443, , , , , new OpenSSLSecureConnection);
		ResultRequest = Client.Post(NewPostRequest);  
		
		Str = ResultRequest.GetBodyAsString();   
		
		WriteLogEvent("Slack.CustomerFormPOST_sendMessageBack_result",,, Str);   
		
	Except 		     
		
	 	Return Response;   
		
	EndTry;   
	
	Return Response;     
	
EndFunction

