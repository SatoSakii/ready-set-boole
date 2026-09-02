CXX			=	c++
CXXFLAGS	=	-Wall -Werror -Wextra

OBJS_DIR	=	.build
INC			=	-Ishared

TESTS		=	tests/run_tests.sh

ex00_SRCS	=	ex00/adder.cpp
ex01_SRCS	=	ex01/multiplier.cpp
ex02_SRCS	=	ex02/gray_code.cpp
ex03_SRCS	=	ex03/eval_formula.cpp
ex04_SRCS	=	ex04/print_truth_table.cpp
ex05_SRCS	=	ex05/negation_normal_form.cpp
ex06_SRCS	=	ex06/conjunctive_normal_form.cpp
ex07_SRCS	=	ex07/sat.cpp
ex08_SRCS	=	ex08/powerset.cpp
ex09_SRCS	=	ex09/eval_set.cpp
ex10_SRCS	=	ex10/map.cpp
ex11_SRCS	=	ex11/reverse_map.cpp

EXOS		=	ex00 ex01 ex02 ex03 ex04 ex05 ex06 ex07 ex08 ex09 ex10 ex11

OBJS		=	$(foreach e,$(EXOS),$(patsubst %.cpp,$(OBJS_DIR)/%.o,$($(e)_SRCS)))
DEPS		=	$(OBJS:.o=.d)

all:	$(EXOS)

test:	all
	@bash $(TESTS)

-include $(DEPS)

define make_exo
$(1): $(1)/$(1)

$(1)/$(1): $$(patsubst %.cpp,$$(OBJS_DIR)/%.o,$$($(1)_SRCS))
	@$$(CXX) $$(CXXFLAGS) $$(INC) $$^ -o $(1)/$(1)
	@echo " $$(GREEN)$$(BOLD)$$(ITALIC)■$$(RESET)  building	$$(GREEN)$$(BOLD)$$(ITALIC)$(1)$$(RESET)"
endef
$(foreach e,$(EXOS),$(eval $(call make_exo,$(e))))

$(OBJS_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@)
	@echo " $(CYAN)$(BOLD)$(ITALIC)■$(RESET)  compiling	$(GRAY)$(BOLD)$(ITALIC)$<$(RESET)"
	@$(CXX) $(CXXFLAGS) $(INC) -o $@ -c $<

clean:
	@echo " $(RED)$(BOLD)$(ITALIC)■$(RESET)  cleaned	$(RED)$(BOLD)$(ITALIC)$(OBJS_DIR)$(RESET)"
	@rm -rf $(OBJS_DIR)

fclean:	clean
	@rm -f $(foreach e,$(EXOS),$(e)/$(e))

re:	fclean all

.PHONY: all clean fclean re $(EXOS)

RED			=	\033[31m
GREEN		=	\033[32m
CYAN		=	\033[36m
GRAY		=	\033[90m
BOLD		=	\033[1m
ITALIC		=	\033[3m
RESET		=	\033[0m