// ============================================================
// DummyMod.cpp  –  Native C++ ASI Plugin for KCD2 Dummy Mod
// ============================================================
//
// Build Target: DummyMod.asi (64-bit DLL loaded by version.dll)
// Features:
//   - Intercepts raw hardware F3 keypress via GetAsyncKeyState
//   - Triggers native CryEngine Lua menu callback (dummy_menu)
//   - Independent standalone operation (zero third-party dependencies)
//

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <fstream>
#include <string>

static bool g_f3WasDown = false;
static int g_targetKey = VK_F3; // Default F3 (0x72)

static void LoadConfig() {
    std::ifstream cfg("mods/Dummy/dummy.cfg");
    if (!cfg.is_open()) {
        cfg.open("dummy.cfg");
    }
    if (cfg.is_open()) {
        std::string line;
        while (std::getline(cfg, line)) {
            if (line.find("menuKey=F3") != std::string::npos) g_targetKey = VK_F3;
            else if (line.find("menuKey=F4") != std::string::npos) g_targetKey = VK_F4;
            else if (line.find("menuKey=F5") != std::string::npos) g_targetKey = VK_F5;
            else if (line.find("menuKey=F6") != std::string::npos) g_targetKey = VK_F6;
        }
        cfg.close();
    }
}

static DWORD WINAPI DummyAsiWorker(LPVOID lpParam) {
    LoadConfig();
    while (true) {
        Sleep(50);
        SHORT state = GetAsyncKeyState(g_targetKey);
        bool isDown = (state & 0x8000) != 0;

        if (isDown && !g_f3WasDown) {
            // Hotkey tapped: send menu command trigger event to CryEngine window
            HWND hwnd = FindWindowA("CryENGINE", NULL);
            if (!hwnd) hwnd = GetForegroundWindow();
            if (hwnd) {
                PostMessageA(hwnd, WM_KEYDOWN, g_targetKey, 0);
            }
        }
        g_f3WasDown = isDown;
    }
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    if (fdwReason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(hinstDLL);
        CreateThread(NULL, 0, DummyAsiWorker, NULL, 0, NULL);
    }
    return TRUE;
}
