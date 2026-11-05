/* Original test-only bridge. The application neither imports nor links this file. */
#include <z3.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

int rhw_oracle(int n, int m, const char *const *values) {
    if (n < 0 || n > 8 || m < 0 || m > 32) return 2;
    for (int i = 0; i < m * (n + 1); ++i) {
        if (values[i] == NULL || strlen(values[i]) > 32) return 2;
        /* The Haskell caller supplies canonical bounded rational numerals. */
        for (const char *s = values[i]; *s; ++s) {
            if (!((*s >= '0' && *s <= '9') || *s == '-' || *s == '/')) return 2;
        }
    }
    Z3_config config = Z3_mk_config();
    Z3_context c = Z3_mk_context(config);
    Z3_del_config(config);
    Z3_sort real = Z3_mk_real_sort(c);
    Z3_ast x[8];
    for (int j = 0; j < n; ++j) {
        char name[8];
        (void)snprintf(name, sizeof(name), "x%d", j);
        x[j] = Z3_mk_const(c, Z3_mk_string_symbol(c, name), real);
    }
    Z3_solver solver = Z3_mk_solver(c);
    Z3_solver_inc_ref(c, solver);
    Z3_params params = Z3_mk_params(c);
    Z3_params_inc_ref(c, params);
    Z3_params_set_uint(c, params, Z3_mk_string_symbol(c, "timeout"), 1000);
    Z3_params_set_uint(c, params, Z3_mk_string_symbol(c, "rlimit"), 1000000);
    Z3_solver_set_params(c, solver, params);
    Z3_params_dec_ref(c, params);
    for (int i = 0; i < m; ++i) {
        Z3_ast terms[8];
        for (int j = 0; j < n; ++j) {
            Z3_ast factors[2] = {
                Z3_mk_numeral(c, values[i * (n + 1) + j], real), x[j]
            };
            terms[j] = Z3_mk_mul(c, 2, factors);
        }
        Z3_ast sum = n == 0 ? Z3_mk_numeral(c, "0", real)
                           : Z3_mk_add(c, (unsigned)n, terms);
        Z3_ast bound = Z3_mk_numeral(c, values[i * (n + 1) + n], real);
        Z3_solver_assert(c, solver, Z3_mk_le(c, sum, bound));
    }
    Z3_lbool answer = Z3_solver_check(c, solver);
    int result = answer == Z3_L_TRUE ? 1 : answer == Z3_L_FALSE ? -1 : 0;
    Z3_solver_dec_ref(c, solver);
    Z3_del_context(c);
    return result;
}
