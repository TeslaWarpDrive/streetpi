import Foundation

public enum HouseReadingCopy {
    public static let unreachableTitle = "The Pi is not answering."
    public static let unreachableDetail = """
    This phone can't see the Pi right now. Nothing was changed. \
    Raspberry Pi Stats will try again on its own.
    """
    public static let emptyTitle = "Nothing to show yet."
    public static let emptyDetail = "When the Pi has a reading, it will show up here."
}
