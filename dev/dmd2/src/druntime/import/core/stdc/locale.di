// D import file generated from 'src\core\stdc\locale.d'
module core.stdc.locale;
extern (C) nothrow 
{
    struct lconv
{
    char* decimal_point;
    char* thousands_sep;
    char* grouping;
    char* int_curr_symbol;
    char* currency_symbol;
    char* mon_decimal_point;
    char* mon_thousands_sep;
    char* mon_grouping;
    char* positive_sign;
    char* negative_sign;
    byte int_frac_digits;
    byte frac_digits;
    byte p_cs_precedes;
    byte p_sep_by_space;
    byte n_cs_precedes;
    byte n_sep_by_space;
    byte p_sign_posn;
    byte n_sign_posn;
    byte int_p_cs_precedes;
    byte int_p_sep_by_space;
    byte int_n_cs_precedes;
    byte int_n_sep_by_space;
    byte int_p_sign_posn;
    byte int_n_sign_posn;
}
    enum LC_CTYPE = 0;
    enum LC_NUMERIC = 1;
    enum LC_TIME = 2;
    enum LC_COLLATE = 3;
    enum LC_MONETARY = 4;
    enum LC_ALL = 6;
    enum LC_PAPER = 7;
    enum LC_NAME = 8;
    enum LC_ADDRESS = 9;
    enum LC_TELEPHONE = 10;
    enum LC_MEASUREMENT = 11;
    enum LC_IDENTIFICATION = 12;
    char* setlocale(int category, in char* locale);
    lconv* localeconv();
}

