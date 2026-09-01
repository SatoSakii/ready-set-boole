#ifndef AST_HPP
# define AST_HPP
# include <string>
# include <stack>
# include <stdexcept>
# include <map>

// Structure représentant un nœud dans l'AST
struct Node
{
	char	symbol;
	Node*	left;
	Node*	right;

	Node(char sym) : symbol(sym), left(nullptr), right(nullptr) {}

	~Node() {
		delete left;
		delete right;
	}
};

// Vérifie si le caractère est un opérande (0 ou 1)
inline bool isOperand(char c)
{
	return (c == '0' || c == '1');
}

// Vérifie si le caractère est un opérateur unaire
inline bool isUnary(char c)
{
	return (c == '!');
}

// Vérifie si le caractère est une variable (A à Z)
inline bool	isVariable(char c)
{
	return (c >= 'A' && c <= 'Z');
}

// Vérifie si le caractère est un opérateur binaire
// Les opérateurs binaires sont '&', '|', '^', '>', '='
inline bool isBinary(char c)
{
	return (c == '&' || c == '|' || c == '^' || c == '>' || c == '=');
}

// Construit un arbre syntaxique abstrait (AST)
// à partir d'une expression booléenne en notation polonaise inversée (RPN)
inline Node *buildTree(const std::string &expr)
{
	std::stack<Node *>	nodes;

	for (char c : expr)
	{
		if (isOperand(c) || isVariable(c))
			nodes.push(new Node(c));
		else if (isUnary(c))
		{
			if (nodes.empty())
				throw std::invalid_argument("Invalid expression");

			Node *operand = nodes.top();

			nodes.pop();

			Node *node = new Node(c);

			node->left = operand;
			nodes.push(node);
		}
		else if (isBinary(c))
		{
			if (nodes.size() < 2)
				throw std::invalid_argument("Invalid expression");

			Node *right = nodes.top();

			nodes.pop();

			Node *left = nodes.top();

			nodes.pop();

			Node *node = new Node(c);

			node->left = left;
			node->right = right;
			nodes.push(node);
		}
		else
			throw std::invalid_argument("Invalid character in expression");
	}

	if (nodes.size() != 1)
		throw std::invalid_argument("Invalid expression");

	return nodes.top();
}

// Évalue un nœud de l'AST en tenant compte des
// valeurs des variables fournies dans la map `values`
inline bool	evalNodeVars(Node *node, const std::map<char, bool> &values)
{
	if (node->symbol >= 'A' && node->symbol <= 'Z')
		return values.at(node->symbol);
	if (isOperand(node->symbol))
		return node->symbol == '1';
	if (isUnary(node->symbol))
		return !evalNodeVars(node->left, values);

	bool	left = evalNodeVars(node->left, values);
	bool	right = evalNodeVars(node->right, values);

	switch (node->symbol)
	{
		case '&': return left && right;
		case '|': return left || right;
		case '^': return left ^ right;
		case '>': return !left || right;
		case '=': return left == right;
		default: throw std::invalid_argument("Invalid operator in expression");
	}
}

// Évalue une formule booléenne représentée sous forme de chaîne de caractères
inline bool evalFormula(const std::string &expr)
{
	Node *root = buildTree(expr);
	bool result = evalNodeVars(root, {});

	delete root;

	return result;
}

#endif