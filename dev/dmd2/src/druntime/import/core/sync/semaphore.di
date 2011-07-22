// D import file generated from 'src\core\sync\semaphore.d'
module core.sync.semaphore;
public import core.sync.exception;

public import core.time;

version (Win32)
{
    private import core.sys.windows.windows;

}
else
{
    version (OSX)
{
    private import core.sync.config;

    private import core.stdc.errno;

    private import core.sys.posix.time;

    private import core.sys.osx.mach.semaphore;

}
else
{
    version (Posix)
{
    private import core.sync.config;

    private import core.stdc.errno;

    private import core.sys.posix.pthread;

    private import core.sys.posix.semaphore;

}
}
}
class Semaphore
{
    this(uint count = 0);
    ~this();
    void wait();
    bool wait(Duration val);
    bool wait(long period)
in
{
assert(period >= 0);
}
body
{
return wait(dur!("hnsecs")(period));
}
    void notify();
    bool tryWait();
    private version (Win32)
{
    HANDLE m_hndl;
}
else
{
    version (OSX)
{
    semaphore_t m_hndl;
}
else
{
    version (Posix)
{
    sem_t m_hndl;
}
}
}

}
version (unittest)
{
    private import core.thread;

    void testWait();
    void testWaitTimeout();
    }
