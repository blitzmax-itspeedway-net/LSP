
Type TLogger 
    Field file:TStream
    Method New()
        Try
            Local filename:String = getEnv_( "LSP-DEBUG" )
            filename="/home/si/dev/LSP/lsp-debug.txt"
            If filename 
                file = OpenFile( filename, False, True )
                If file SeekStream( file, file.Size())
            End If
            Print "- Opening log"
            Self.write( "STARTEDx" )
        Catch e:String
            ' Show the error, but otherwise just continue
            DebugLog( "Error: "+e )
            Print "ERROR "+e
        End Try
    End Method

    Method Write( message:String )
        If Not file 
            Print( "FILE NOT OPEN" )
            Return
        End If
        Print( message )
        WriteLine( file, message )
        file.flush()
    End Method

    Method Close()
        Print "- Closing log"
        If file CloseStream( file )
        file = Null
    End Method
End Type