SuperStrict
'	GENERAL PARSER

Framework brl.retro
'Import brl.collections
'Import brl.map
Import brl.reflection
'
Include "bin/loadfile().bmx"
Include "bin/TException.bmx"

'	GENERIC LEXER AND PARSER
Include "bin/TToken.bmx"
Include "bin/TLexer.bmx"
Include "bin/TParser.bmx"

' 	ABNF GRAMMAR PARSER
Include "bin/TABNF.bmx"
Include "bin/TABNFLexer.bmx"
Include "bin/TABNFParser.bmx"

'	BLITZMAX PARSER
Include "bin/lexer-const-bmx.bmx"
Include "bin/TBlitzMaxLexer.bmx"
Include "bin/TBlitzMaxParser.bmx"

'	DELIVERABLES
Include "bin/AbstractSyntaxTree.bmx"
Include "bin/TSymbolTable.bmx"


Type AST_BinaryOperator Extends AST
	Field L:AST	' Left 
	Field R:AST	' Right
	
	Method New( L:AST, token:TToken, R:AST )
		Self.token = token
		Self.L = L
		Self.R = R
	End Method
	
End Type


Function Publish:Int( event:String, data:Object=Null, extra:Object=Null )
    Print "---> "+event
End Function



Type TLangServ Extends TVisitor

	Field parser:TParser
	Field tree:AST
	
	Method New( parser:TParser )
		Self.parser = parser
	End Method
	
	Method run()
		' Perform the actual Parsing here
		parser.parse()
		tree = parser.ast
		' Now call the visitor to process the tree
		visit( tree )
	End Method
	
	' Not sure how to debug this yet...!
	' Maybe dump the syntax tree and definition table?
	Method reveal:String()
	End Method
	
	' ABSTRACT METHODS
	' Not all of them are required by the Language server, but "bcc" will need them
	
	Method visit_binaryoperator( node:AST_BinaryOperator )
		If Not node ThrowException( "Invalid node in binaryoperator" ) 
		Print "BINARY OPERATION"
	
		Select node.token.value
		Case "+"	; 'Local x:Int = visit( node.L ) + visit( node.R )
		Case "-"	
		Case "*"
		Case "/"
		End Select
		
	End Method
	
End Type
		
'Local token:TToken = goal.entry

Rem
Now we need To read the node tree, obtain symbols from lexer compar To make sure syntax is correct
Create the AST, Syntz table (For document) And defnintion tree..

Phew!
End Rem

'	CREATE TEST NODE TREE
'	(As we have no BlitzMax BNF Defintion to read from we will do all this manually)

'function name ":" 


' DEMO CODE ONLY

' Lets manually build a tree with the expression 2+(3*4)

' Create a node for the number tokens (Which would come from the lexer)
'Local Number2:AST = New AST( New TToken( "number", "2",0,0 ) )
'Local Number3:AST = New AST( New TToken( "number", "3",0,0 ) )
'Local Number4:AST = New AST( New TToken( "number", "4",0,0 ) )

' Built the Abstract Syntax Tree
'Local addnode:AST_BinaryOperator = New AST_BinaryOperator( ..
'	Number2, ..
'	New TToken( "symbol","+",0,0 ), ..
'	New AST_BinaryOperator( ..
'		Number3, ..
'		New TToken( "symbol", "*",0,0 ), ..
'		Number4 ))

' Now lets test parsing 

Local source:String, lexer:TLexer, parser:TParser
Local start:Int, finish:Int
Local abnf:TABNF, tree:AST
Try
	
	'	First we load and parse BlitzMax Grammar into abnf
	source = loadFile( "samples/bmx-build.abnf" )
	lexer  = New TABNFLexer( source )
	parser = New TABNFParser( lexer )	
	start  = MilliSecs()
	abnf   = TABNF( parser.parse() )
	finish = MilliSecs()
	Print( "ABNF LEXER+PARSE TIME: "+(finish-start)+"ms" )
	
	'	Save the Grammar Definition
	'abnf = parser.abnf
'DebugStop
	Print "~nABNF:"
	Print abnf.reveal()
	
	'	Next we load and parse BlitzMax
	source = loadFile( "samples/1) Simple Blitzmax.bmx" )
	'source = loadFile( "samples/1) Simple Blitzmax.bmx" )
	lexer  = New TBlitzMaxLexer( source )
'DebugStop
	parser = New TBlitzMaxParser( lexer, abnf )		' NOTE LANGUAGE DEFINITION ARGUMENT HERE
	start  = MilliSecs()
DebugStop
	tree   = AST(parser.parse())
	finish = MilliSecs()
	Print( "BLITZMAX LEXER+PARSE TIME: "+(finish-start)+"ms" )
	
'	parser.testabnf( "program" )
	
	'parser.parse()
	Print parser.reveal()
	'Local langserv:TLangServ = New TLangServ( parser )

	'langserv.run()
	'Print langserv.reveal()

Catch exception:TException
	Print "## Exception: "+exception.toString()+" ##"
End Try



