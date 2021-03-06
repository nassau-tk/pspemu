
import std.stdio;
import std.file;
import std.conv;

int main(string[] args)
{
    int w_total;
    int l_total;
    int c_total;

    writeln("   lines   words   bytes file");

    foreach (arg; args[1 .. $])
    {
        string input;
        int w_cnt, l_cnt, c_cnt;
        int inword;

        input = to!string(std.file.read(arg));

        foreach (char c; input)
        {
            if (c == '\n')
                ++l_cnt;

            if (c != ' ')
            {
                if (!inword)
                {
                    inword = 1;
                    ++w_cnt;
                }
            }
            else
                inword = 0;

            ++c_cnt;
        }

        writefln("%8s%8s%8s %s\n", l_cnt, w_cnt, c_cnt, arg);
        l_total += l_cnt;
        w_total += w_cnt;
        c_total += c_cnt;
    }

    if (args.length > 2)
    {
        writefln("--------------------------------------\n%8s%8s%8s total", 
                 l_total, w_total, c_total);
    }

    return 0;
}
