#include <iostream>
#include <cstdlib>
#include "colors.hpp"

int	adder(unsigned int a, unsigned int b)
{
	while (b != 0)
	{
		// Calculer la retenue (carry)
		unsigned int carry = a & b;

		// Mettre à jour a et b pour la prochaine itération
		// XOR pour addition sans retenue
		a = a ^ b;

		// Mettre à jour b avec la retenue décalée d'un bit
		// Décaler la retenue d'un bit vers la gauche
		b = carry << 1;
	}

	return (a);
}

int	main(int argc, char **argv)
{
	if (argc != 3)
	{
		std::cerr << USAGE(0, argv[0] << " <num1> <num2>") << std::endl;
		return (1);
	}

	unsigned int num1 = std::atoi(argv[1]);
	unsigned int num2 = std::atoi(argv[2]);

	std::cout << RESULT(0, adder(num1, num2)) << std::endl;

	return (0);
}