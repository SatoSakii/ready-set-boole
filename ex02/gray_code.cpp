#include <iostream>
#include <cstdlib>
#include "colors.hpp"

// Convertit un entier en code Gray.
// Exemple : gray_code(3) renvoie 2 (en binaire : 11 -> 10)
unsigned int	gray_code(unsigned int a)
{
	return (a ^ (a >> 1));
}

int	main(int argc, char **argv)
{
	if (argc != 2)
	{
		std::cerr << USAGE(2, argv[0] << " <num1>") << std::endl;
		return (1);
	}

	unsigned int num1 = std::strtoul(argv[1], nullptr, 10);

	std::cout << RESULT(2, gray_code(num1)) << std::endl;

	return (0);
}