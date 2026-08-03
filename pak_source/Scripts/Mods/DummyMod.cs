// DummyMod.cs - C# Unmanaged Native Proxy for DummyMod.asi
using System;
using System.Runtime.InteropServices;
using System.Threading;

public class DummyAsi
{
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    public static void Initialize()
    {
        Thread t = new Thread(new ThreadStart(WorkerThread));
        t.IsBackground = true;
        t.Start();
    }

    private static void WorkerThread()
    {
        bool wasDown = false;
        int vkF3 = 0x72; // VK_F3

        while (true)
        {
            Thread.Sleep(50);
            short state = GetAsyncKeyState(vkF3);
            bool isDown = (state & 0x8000) != 0;

            if (isDown && !wasDown)
            {
                // Key tapped
            }
            wasDown = isDown;
        }
    }
}
