using System.Collections.Generic;

namespace VerbalCommands.RouterScript
{
	// Brief 17: the parsed script. The parser builds these; the compiler checks them and turns them
	// into instructions. Every node keeps its line for error messages.

	internal abstract class Node
	{
		public int line;
	}

	// ---- Expressions ----

	internal abstract class Expr : Node
	{
	}

	internal sealed class LiteralExpr : Expr
	{
		public Value value;     // none, true/false, a number or text (never a list or dict)
	}

	internal sealed class NameExpr : Expr
	{
		public string name;
	}

	internal sealed class ListExpr : Expr
	{
		public List<Expr> items = new List<Expr>();
	}

	internal sealed class DictExpr : Expr
	{
		public List<Expr> keys = new List<Expr>();
		public List<Expr> values = new List<Expr>();
	}

	internal sealed class IndexExpr : Expr
	{
		public Expr target;
		public Expr index;
	}

	internal sealed class CallExpr : Expr
	{
		public string name;
		public List<Expr> args = new List<Expr>();
	}

	internal sealed class UnaryExpr : Expr
	{
		public string op;       // "-" or "not"
		public Expr operand;
	}

	internal sealed class BinaryExpr : Expr
	{
		public string op;       // + - * / % == != < > <= >= in "not in" and or
		public Expr left;
		public Expr right;
	}

	// ---- Statements ----

	internal abstract class Stmt : Node
	{
	}

	internal sealed class AssignStmt : Stmt
	{
		public Expr target;     // NameExpr or IndexExpr
		public Expr value;
	}

	internal sealed class ExprStmt : Stmt
	{
		public Expr expr;
	}

	internal sealed class IfStmt : Stmt
	{
		public List<Expr> conditions = new List<Expr>();        // the if, then each elif
		public List<List<Stmt>> blocks = new List<List<Stmt>>(); // one per condition
		public List<Stmt> elseBlock;                             // null when there is no else
	}

	internal sealed class ForStmt : Stmt
	{
		public string variable;
		public Expr items;
		public List<Stmt> body = new List<Stmt>();
	}

	internal sealed class WhileStmt : Stmt
	{
		public Expr condition;
		public List<Stmt> body = new List<Stmt>();
	}

	internal sealed class BreakStmt : Stmt
	{
	}

	internal sealed class ContinueStmt : Stmt
	{
	}

	internal sealed class ReturnStmt : Stmt
	{
		public Expr value;      // null for a bare return
	}

	internal sealed class FunctionStmt : Stmt
	{
		public string name;
		public List<string> parameters = new List<string>();
		public List<Stmt> body = new List<Stmt>();
		public bool topLevel;
	}
}
