import CoreGraphics

let screens = [
    ScreenInfo(index: 0, displayID: 1, bounds: CGRect(x: -1920, y: -180, width: 1920, height: 1080)),
    ScreenInfo(index: 1, displayID: 2, bounds: CGRect(x: 0, y: 0, width: 1440, height: 900)),
    ScreenInfo(index: 2, displayID: 3, bounds: CGRect(x: 1440, y: 120, width: 1920, height: 1080))
]

precondition(ScreenLayout.nextScreen(after: screens[0], in: screens) == screens[1])
precondition(ScreenLayout.nextScreen(after: screens[1], in: screens) == screens[2])
precondition(ScreenLayout.nextScreen(after: screens[2], in: screens) == screens[0])
