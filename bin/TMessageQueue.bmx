
'   LANGUAGE SERVER EXTENSION FOR BLITZMAX NG
'   (c) Copyright Si Dunford, June 2021, All Right Reserved
'   MESSAGE QUEUE

Rem Event Lifecycle Explained

	JSON Message arrives from client
	LSP Receiver Thread packages this up into an event
		Event ID:	EV_messageReceived event
		Extra:		Original JSON message
	Message queue receives this event
		Validates JSON.Method
		If Extra (JSON) contains an ID
			Adds message to the message queue
		If Extra (JSON) does not contain an ID
			(It is a notification)
			Emits an event
				Event ID:	Matches the Method in the request
				Extra:		Original JSON message
	Messagequeue processes queue
		Next message is emitted as an event
			Event ID:	Matches the Method in the request
			Extra:		Original JSON message
	Message queue processes CANCEL EVENTS
		Loops through message queue and flags message as cancelled.

End Rem

Type TMessageQueue Extends TObserver
    Global requestThread:TThread
    Global sendqueue:TQueue<String>         ' Messages waiting to deliver to Language Client
    Global taskqueue:TIntMap                ' Tasks Waiting or Running
    ' Locks
    Field sendMutex:TMutex = CreateMutex()
    Field taskMutex:TMutex = CreateMutex()
    ' Semaphores
    Field sendCounter:TSemaphore = CreateSemaphore( 0 )
    'Field taskCounter:TSemaphore = CreateSemaphore( 0 )

    Method New()
        sendQueue = New TQueue<String>()
        taskQueue = New TIntMap()
'DebugStop

		' V0.3, Start Event Listener
		listen()
		
        ' Subscribe to messages
        Subscribe( ["pushtask","sendmessage","exitnow","cancelrequest"] )
    End Method

	Method Close()
		unlisten()
		PostSemaphore( sendCounter )
	End Method

    ' Get next waiting message in the queue
    Method getNextTask:TMessage()
        If taskqueue.isEmpty() Return Null
        Publish( "getNextTask()" )
        LockMutex( TaskMutex )
        For Local task:TMessage = EachIn taskqueue.values()
            ' Debugging
            Local state:String =  ["waiting","running","complete"][task.state]
            If task.cancelled state :+ ",cancelled"
            Publish( "debug", "Task "+task.id+" ["+state+"]")
            '
            If task.cancelled 
				'JSON RPC REQUIRES THAT EVERY REQUEST SENDS BACK A RESPONSE
				SendMessage( Response_OK( task.id ) )
                taskqueue.remove( task.id )
			ElseIf task.state=STATE_COMPLETE
                Publish( "Closing Task "+task.id)
                taskqueue.remove( task.id )
            ElseIf task.state = STATE_WAITING
                'Publish( "Task "+task.id+" waiting")
                task.state = STATE_RUNNING
                UnlockMutex( TaskMutex )
                Return task
            'else
            '    Publish( "Task "+task.id+" running")
            End If
        Next
        UnlockMutex( TaskMutex )
        Return Null
    End Method

    ' Remove a message from the queue 
    Method removeTask( task:TMessage )
        LockMutex( TaskMutex )
        taskqueue.remove( task.id )
        UnlockMutex( TaskMutex )
    End Method
    
    ' Retrieve a message from send queue
    Method popSendQueue:String()
        LockMutex( sendMutex )
        Local result:String = String( sendqueue.dequeue() )
        UnlockMutex( sendMutex )
        Return result
    End Method

    ' Observations
    Method Notify( event:String, data:Object, extra:Object )
        Select event
        Rem 31/8/21, Moved to V0.3 event handler
		Case "cancelrequest"   '$/cancelRequest
            ' A request has been cancelled
            Local node:JSON = JSON( data )
            If Not node Return
            Local id:Int = node.toInt()
            LockMutex( taskmutex )
            For Local task:TMessage = EachIn taskqueue
                If task.id = id 
                    task.cancelled = True
                    Exit
                End If
            Next
            UnlockMutex( taskMutex )
        Case "sendmessage"         ' Send a message to the language client
            pushSendQueue( String(data) )
        Case "pushtask"             ' Add a task to the task queue
            Publish( "debug", "Pushtask received")
            Local task:TMessage = TMessage(data)
            If task pushTaskQueue( task )
            Publish( "debug", "Pushtask done" )
		EndRem
        Case "exitnow"      ' System exit requested
            ' Force waiting threads to exit
            PostSemaphore( sendCounter )
            'PostSemaphore( taskCounter )
        Default
            Publish( "error", "TMessageQueue: event '"+event+"' ignored" )
        End Select
    End Method

    Private

    ' Add a new message to the queue
    Method pushTaskQueue( task:TMessage )
        'Publish( "debug", "PushTaskQueue()" )
        If Not task Return
        'Publish( "debug", "- task is not null" )
        LockMutex( TaskMutex )
        'Publish( "debug", "- task mutex locked" )
        taskqueue.insert( task.id, task )
        'Publish( "debug", "- task inserted" )
        'PostSemaphore( taskCounter )
        'Publish( "debug", "- task Semaphore Incremented" )
        UnlockMutex( TaskMutex )
        'Publish( "debug", "- task mutex unlocked" )
    End Method
   
    ' Add a message to send queue
    Method pushSendQueue( message:String )
        message = Trim( message )
        If message="" Return
        LockMutex( sendMutex )
        sendqueue.enqueue( message )
        PostSemaphore( sendCounter )    ' Increase message counter semaphore
        UnlockMutex( sendMutex )
    End Method

	' Raises an event for a message
	'Method TaskToEvent( task:TMessage )
		'TMSG.emit()
	'End Method

	Public
	
	' V0.3 EVENT HANDLERS
	
	' Received a message from the client
	Method onReceivedFromClient:Int( message:TMessage )		
		Publish( "debug", "TMessageQueue.onReceivedFromClient()")

		' Pre-mark message as complete
		message.state = STATE_COMPLETE
		
		' Message.Extra contains the original JSON from client
		Local J:JSON = JSON( message.extra )
		If Not J 
			SendMessage( Response_Error( ERR_INVALID_REQUEST, "Invalid request" ) )
			Return False
		End If
		
		' Check for a method
		Local node:JSON = J.find("method")
		If Not node 
			SendMessage( Response_Error( ERR_METHOD_NOT_FOUND, "No method specified" ) )
			Return False
		End If
		
		' Validate methd
		Local methd:String = node.tostring()
		If methd = "" 
			SendMessage( Response_Error( ERR_INVALID_REQUEST, "Method cannot be empty" ) )
			Return False
		End If
		
		' Extract "Params" if it exists (which it should)
		'If J.contains( "params" )
		Local params:JSON = J.find( "params" )
		'End If

		Publish( "debug", "- ID:      "+message.getid() )
		Publish( "debug", "- METHOD:  "+methd )
		Publish( "debug", "- REQUEST: "+J.stringify() )
		'Publish( "debug", "- PARAMS:  "+params.stringify() )

		' An ID indicates a request message
		If J.contains( "id" )
			Publish( "debug", "- REQUEST" )
			' This is a request, add to queue
			Publish( "debug", "Pushing request '"+methd+"' to queue")
			pushTaskQueue( New TMessage( methd, J, params ) )
			Return False
		End If
					
		' The message is a notification, send it now.
		Publish( "debug", "- NOTIFICATION" )
		Publish( "debug", "Executing notification "+methd )
		New TMessage( methd, J, params ).emit()
		Return False
	End Method
	
	' Sending a message to the client
	Method onSendToClient:Int( message:TMessage )
		'Publish( "debug", "TMessageQueue.OnSendtoClient()" )

		' Pre-mark message as complete
		message.state = STATE_COMPLETE

		' Message.Extra contains the JSON being sent
		Local J:JSON = JSON( message.extra )
		If Not J Return False ' If it isn't there, do nothing!
		
		' Extract message
		Local text:String = J.stringify()
		publish( "debug", "TMessageQueue.onSendToClient()~n"+text )
		If text ; pushSendQueue( text )
		Return False
	End Method	

	' Cancel Request
	Method OnCancelRequest:Int( message:TMessage )
		' Pre-mark message as complete
		message.state = STATE_COMPLETE

		' Message.Extra contains the original JSON being sent
		' Message.Params contains the parameters
		If Not message Or Not message.params ; Return True

		Local Jid:JSON = message.params.find( "id" )
		If Not Jid
			SendMessage( Response_Error( ERR_INVALID_REQUEST, "Missing ID" ) )
			Return False
		End If
		'
		Local id:String = Jid.toString()
		LockMutex( taskmutex )
		For Local task:TMessage = EachIn taskqueue
			If task.id = id 
				task.cancelled = True
				Exit
			End If
		Next
		UnlockMutex( taskMutex )
		Return False
	End Method

End Type

Function Response_Error:JSON( code:String, message:String, id:String="null" )
    Publish( "log", "ERRR", message )
    Local response:JSON = New JSON()
    response.set( "id", id )
    response.set( "jsonrpc", JSONRPC )
    response.set( "error", [["code",code],["message","~q"+message+"~q"]] )
    Return response	'.stringify()
End Function

Function Response_OK:JSON( id:String="null" )
    Publish( "log", "INFO", "ResponseOK" )
	Local response:JSON = New JSON()
	response.set( "id", id )
	response.set( "jsonrpc", JSONRPC )
	response.set( "result", "null" )
    Return response '.stringify()
	'Return "{~qid~q:"+id+",~qjsonrpc~q:"+JSONRPC+",~qresult~q:null}"
End Function


