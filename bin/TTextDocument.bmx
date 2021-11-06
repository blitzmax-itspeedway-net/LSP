
'	LANGUAGE SERVER / TEXT DOCUMENT
'	(c) Copyright Si Dunford, July 2021, All Rights Reserved

' Interface based on vscode-languageserver-node
' https://github.com/microsoft/vscode-languageserver-node/blob/bc2cb78ed791e297f4f91bdb91934b251f93ff78/textDocument/src/main.ts#L116

Interface ITextDocument
		
	Method getText:String( range:TRange = Null )
	Method positionAt:TPosition( offset:UInt )
	Method offsetAt:UInt( position:TPosition )
	
End Interface

' A TTextDocument is not currently open in the language client
Type TTextDocument Implements ITextDocument

	Private
	
	Field uri : TURI
	Field languageId : String
	Field version : ULong		' Incremented after each change including Undo/Redo
	'Field lineCount: UInt

	' Language server specific
	Field symbols:TSymbolTable
		
	Public

	Field content:String
	Field validated:Int = False		' Used by validation thread to identify documents requiring validation

	Method New( uri:TURI, content:String="", version:ULong = 0 )
		Self.uri = uri
		Self.content = content
		Self.version = version
	End Method

	Method get_languageId:String()	;	Return languageId				;	End Method
	Method get_uri:TURI()			;	Return uri						;	End Method
	Method get_version:Int()		;	Return version					;	End Method

	Method getText:String( range:TRange = Null ) 	;	End Method
	Method positionAt:TPosition( offset:UInt ) 		;	End Method
	Method offsetAt:UInt( position:TPosition )		;	End Method
	
	Method validate() 				;	validated = True				;	End Method
End Type

' A TFullTextDocument is open in the language client

Type TFullTextDocument Extends TTextDocument

	Private
	
	Field lineOffsets:UInt[]
	
	' Language server specific
	Field ast:TASTNode
	Field lexer:TLexer
		
	Public
	
	Method New( uri:TURI, languageId:String, content:String, version:ULong )
		Self.uri = uri
		Self.languageId = languageId
		Self.version = version
		Self.content = content
		lineOffsets = []
	End Method

	Method change( changes:JSON[], version:UInt )
		logfile.debug( "TTextDocument.change() is not implemented" )
		Self.version = version
	End Method

	Method get_lineCount:UInt()		; 	Return getLineOffsets().length	;	End Method
		
	Method getLineOffsets:UInt[]()
		If lineOffsets = [] ; lineOffsets = computeLineOffsets( content, True )
		Return lineOffsets
	End Method
	
	Method getText:String( range:TRange = Null )
		If Not range Return content
		Local rangeStart:UInt = offsetAt( range.start )
		Local rangeEnd:UInt = offsetAt( range.ends )
		Return content[ rangeStart..rangeEnd ]
	End Method

	Method offsetAt:UInt( position:TPosition )
		Local lineOffsets:UInt[] = getLineOffsets()
		If position.line >= lineOffsets.length Return content.length
		If position.line < 0 Return 0
		Local lineOffset:UInt = lineOffsets[ position.line ]
		Local nextLineOffset:UInt
		If position.line + 1 < lineOffsets.length
			nextLineOffset = lineOffsets[position.line + 1]
		Else
			nextLineOffset = content.length
		End If
		Return Max( Min( lineOffset + position.character, nextLineOffset), lineOffset)
	End Method

	' Get the Postion at a cursor index
	Method positionAt:TPosition( offset:UInt )

		offset = Max( Min( offset, content.length ), 0)

		Local lineOffsets:UInt[] = getLineOffsets()
		Local low:UInt = 0
		Local high:UInt = lineOffsets.length
		If high = 0	; Return New TPosition( 0, offset )
		
		While low < high
			Local middle:UInt = Floor( (low + high) / 2)
			If lineOffsets[ middle ] > offset
				high = middle
			Else
				low = middle + 1
			End If
		Wend
		' low is the least x For which the line offset is larger than the Current offset
		' Or array.length If no line offset is larger than the Current offset
		Local line:UInt = low -1
		Return New TPosition( line, offset - lineOffsets[line] )
	End Method
		
Rem

	Public update(changes: TextDocumentContentChangeEvent[], version: number): void {
		For (let change of changes) {
			If (FullTextDocument.isIncremental(change)) {
				// makes sure start is before End
				Const range = getWellformedRange(change.range);

				// update content
				Const startOffset = this.offsetAt(range.start);
				Const endOffset = this.offsetAt(range.End);
				this._content = this._content.substring(0, startOffset) + change.text + this._content.substring(endOffset, this._content.length);

				// update the offsets
				Const startLine = Math.Max(range.start.line, 0);
				Const endLine = Math.Max(range.End.line, 0);
				let lineOffsets = this._lineOffsets!;
				Const addedLineOffsets = computeLineOffsets(change.text, False, startOffset);
				If (endLine - startLine === addedLineOffsets.length) {
					For (let i = 0, Len = addedLineOffsets.length; i < Len; i++) {
						lineOffsets[i + startLine + 1] = addedLineOffsets[i];
					}
				} Else {
					If (addedLineOffsets.length < 10000) {
						lineOffsets.splice(startLine + 1, endLine - startLine, ...addedLineOffsets);
					} Else { // avoid too many arguments For splice
						this._lineOffsets = lineOffsets = lineOffsets.slice(0, startLine + 1).concat(addedLineOffsets, lineOffsets.slice(endLine + 1));
					}
				}
				Const diff = change.text.length - (endOffset - startOffset);
				If (diff !== 0) {
					For (let i = startLine + 1 + addedLineOffsets.length, Len = lineOffsets.length; i < Len; i++) {
						lineOffsets[i] = lineOffsets[i] + diff;
					}
				}
			} Else If (FullTextDocument.isFull(change)) {
				this._content = change.text;
				this._lineOffsets = undefined;
			} Else {
				Throw New Error('Unknown change event received');
			}
		}
		this._version = version;
	}









	Private static isIncremental(event: TextDocumentContentChangeEvent): event is { range: Range; rangeLength?: number; text: String; } {
		let candidate: { range: Range; rangeLength?: number; text: String; } = event as any;
		Return candidate !== undefined && candidate !== Null &&
			typeof candidate.text === 'string' && candidate.range !== undefined &&
			(candidate.rangeLength === undefined || typeof candidate.rangeLength === 'number');
	}

	Private static isFull(event: TextDocumentContentChangeEvent): event is { text: String; } {
		let candidate: { range?: Range; rangeLength?: number; text: String; } = event as any;
		Return candidate !== undefined && candidate !== Null &&
			typeof candidate.text === 'string' && candidate.range === undefined && candidate.rangeLength === undefined;
	}
End Rem

'	Method parse()
'		If content = "" Return
		
		' PARSE THE SOURCE
'		lexer = New TBlitzMaxLexer( content )
'		Local parser:TParser = New TBlitzMaxParser( lexer )
'DebugStop	
'		ast = parser.parse_ast()

'logfile.debug( "FILE '"+uri.tostring()+"':" )
'logfile.debug( lexer.reveal() )
'logfile.debug( parser.reveal() )
'logfile.debug( ast.reveal() )

'	End Method

	Method validate()
		If Not validated And content <> ""
			logfile.debug( "> Parsing "+uri.tostring() )
			lexer = New TBlitzMaxLexer( content )
			Local parser:TParser = New TBlitzMaxParser( lexer )
			ast = parser.parse_ast()

			'logfile.debug( "FILE '"+uri.tostring()+"':" )
			'logfile.debug( lexer.reveal() )
			'logfile.debug( parser.reveal() )
			'logfile.debug( ast.reveal() )
			
			' Send diagnostics to client
			sendDiagnostics()
		End If		
		
		' Mark document as validated
		validated = True
	End Method

	'Method DocumentSymbolProvider()
	'End Method

	Method sendDiagnostics()
	
		logfile.debug( "# DIAGNOSTICS" )
		Local list:TDiagnostic[]
		list = TDiagnostic[]( ast.inorder( GetDiagnostic, list, 0 ) )
		
		' Convert diagnostics into a string so we can display it
		Local result:String
		For Local diag:TDiagnostic = EachIn list
			result :+ diag.reveal()+"~n"
		Next
		logfile.debug( result )
		
		' Convert diagnostics into JSON and send to client
		Local diagnostics:JSON = New JSON( JSON_Array )
		
		Local diagnostic:JSON = New JSON()
		diagnostic.set( "range", JRange( 0,0,1,0 ) )
		diagnostic.set( "severity", DiagnosticSeverity.hint.ordinal() )
		diagnostic.set( "code", 99 )
		diagnostic.set( "codeDescription", "Additional information" )
		diagnostic.set( "source", "BLS!" )
		diagnostic.set( "message", "THis is a test diagnostic" )
		'diagnostic.set( "tags", [] )
		'diagnostic.set( "relatedInformation", 0 )
		'diagnostic.set( "data", 0 )

		diagnostics.addlast( diagnostic )

		Local message:JSON = EmptyMessage( "textDocument/publishDiagnostics" )
		message.set( "params|uri", uri.tostring() )
		message.set( "params|version", version )
		message.set( "params|diagnostics", diagnostics )
	
		logfile.debug( "DIAGNOSTICS:~n"+message.prettify() )
		
		client.send( message )
		
		Function GetDiagnostic:Object( node:TASTNode, data:Object, options:Int )
'DebugStop
			If node.errors.length = 0 Return data
'DebugStop
			' Convert data into a list and append to it
			Local list:TDiagnostic[] = TDiagnostic[]( data )
			'Local result:String
			'For Local i:Int = 0 Until node.errors.length
				'list :+ [ node.errors[i] ]
				'result :+ errors[n] + "["+node.line+","+node.pos+"] "+node.error+" ("+node.getname()+")~n"
				'result :+ errors[n] + "["+node.line+","+node.pos+"] ("+node.getname()+")~n"
			'	list.addlast( error )
			'Next 
			Return list + node.errors
		End Function
		
	End Method

End Type

Function computeLineOffsets:UInt[]( Text:String, isAtLineStart:Int, textOffset:UInt = 0)
	Local result:UInt[] 
	If isAtLineStart ; result = [textOffset]	
	For Local i:UInt = 0 Until Text.length
		Local ch:Int = Asc( Text[i..i+1] )
		If ch=TK_CR Or ch=TK_LF
			If ch = TK_CR And i+1 < Text.length And Asc(Text[(i+1)..(i+2)]) = TK_LF ; i:+1
			result :+ [textOffset + i + 1]
		End If
	Next
	Return result
EndFunction 
