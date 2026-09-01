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

	return (nodes.top());
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

	return (result);
}

// Convertit un arbre syntaxique abstrait (AST) en notation polonaise inversée (RPN)
inline std::string	treeToRPN(Node *node)
{
	if (isVariable(node->symbol) || isOperand(node->symbol))
		return (std::string(1, node->symbol));
	if (isUnary(node->symbol))
		return (treeToRPN(node->left) + node->symbol);

	return (treeToRPN(node->left) + treeToRPN(node->right) + node->symbol);
}

// Crée une copie d'un arbre syntaxique abstrait (AST)
inline Node	*copyTree(Node *node)
{
	if (!node)
		return (nullptr);

	Node	*copy = new Node(node->symbol);

	copy->left = copyTree(node->left);
	copy->right = copyTree(node->right);

	return (copy);
}

// Pousse les négations vers le bas de l'arbre syntaxique abstrait (AST)
// en appliquant les lois de De Morgan.
inline Node *pushNegation(Node *node)
{
	if (isVariable(node->symbol) || isOperand(node->symbol))
		return (node);

	if (isUnary(node->symbol))
	{
		Node *child = node->left;

		if (isUnary(child->symbol))
		{
			Node *tmp = child->left;

			child->left = nullptr;
			delete child;

			return (pushNegation(tmp));
		}
		if (isBinary(child->symbol))
		{
			Node	*notL = new Node('!');
			Node	*notR = new Node('!');

			notL->left = child->left;
			notR->left = child->right;

			child->left = notL;
			child->right = notR;
			child->symbol = (child->symbol == '&') ? '|' : '&';

			node->left = nullptr;

			delete node;

			return (pushNegation(child));
		}
	}

	node->left = pushNegation(node->left);
	if (node->right)
		node->right = pushNegation(node->right);

	return (node);
}

// Supprime les opérateurs '>' (implication), '=' (équivalence)
// et '^' (XOR) en les remplaçant par des combinaisons d'opérateurs
// AND, OR et NOT équivalentes.
// A=B <=> (A&B) | (!A & !B)
inline Node *deleteOperator(Node *node)
{
	if (isVariable(node->symbol) || isOperand(node->symbol))
		return (node);

	node->left = deleteOperator(node->left);
	if (node->right)
		node->right = deleteOperator(node->right);

	if (node->symbol == '>')
	{
		Node *notLeft = new Node('!');

		notLeft->left = node->left;
		node->symbol = '|';
		node->left = notLeft;
	}
	else if (node->symbol == '=')
	{
		Node *left = node->left;
		Node *right = node->right;
		Node *leftCopy = copyTree(left);
		Node *rightCopy = copyTree(right);

		Node *leftAnd = new Node('&');
		Node *notLeft = new Node('!');
		Node *notRight = new Node('!');
		Node *rightAnd = new Node('&');

		leftAnd->left = left;
		leftAnd->right = right;

		notLeft->left = leftCopy;
		notRight->left = rightCopy;
		rightAnd->left = notLeft;
		rightAnd->right = notRight;

		node->symbol = '|';
		node->left = leftAnd;
		node->right = rightAnd;
	}
	else if (node->symbol == '^')
	{
		Node *left = node->left;
		Node *right = node->right;
		Node *leftCopy = copyTree(left);
		Node *rightCopy = copyTree(right);

		Node *notLeft = new Node('!');
		Node *leftAnd = new Node('&');
		Node *notRight = new Node('!');
		Node *rightAnd = new Node('&');

		notLeft->left = leftCopy;
		leftAnd->left = notLeft;
		leftAnd->right = rightCopy;

		notRight->left = right;
		rightAnd->left = left;
		rightAnd->right = notRight;

		node->symbol = '|';
		node->left = leftAnd;
		node->right = rightAnd;
	}
	return (node);
}

// Convertit une formule booléenne en forme normale négative (NNF).
inline std::string	negationNormalForm(const std::string &formula)
{
	Node	*root = buildTree(formula);

	root = deleteOperator(root);
	root = pushNegation(root);

	std::string	result = treeToRPN(root);

	delete root;

	return (result);
}

#endif