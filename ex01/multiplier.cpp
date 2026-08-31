#include <iostream>
#include <cstdlib>
#include "colors.hpp"

int	multiply(unsigned int a, unsigned int b)
{
	int result = 0;

	while (b != 0)
	{
		// Si le bit de poids faible de b est 1, ajouter a au résultat
		if (b & 1)
			result += a;

		// Décaler a d'un bit vers la gauche et b d'un bit vers la droite
		a <<= 1;
		b >>= 1;
	}

	return (result);
}

int	main(int argc, char **argv)
{
	if (argc != 3)
	{
		std::cerr << USAGE(1, argv[0] << " <num1> <num2>") << std::endl;
		return (1);
	}

	unsigned int num1 = std::atoi(argv[1]);
	unsigned int num2 = std::atoi(argv[2]);

	std::cout << RESULT(1, multiply(num1, num2)) << std::endl;

	return (0);
}