//+------------------------------------------------------------------+
//|                                               GridMaster Pro.mq5 |
//|                                           Copyright 2024, Sajid. |
//|                    https://www.mql5.com/en/users/sajidmahamud835 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Sajid."
#property link      "https://www.mql5.com/en/users/sajidmahamud835"
#property version   "1.04"
#property strict

//--- Input parameters
input double LotSize = 0.1;
input int MaxOrders = 10;         // Maximum number of orders in the grid
input int ATRPeriod = 14;         // ATR period for dynamic grid adjustment
input double ATRMultiplier = 1.5; // Multiplier for ATR to calculate grid distance
input int TrendPeriod = 50; // Period for detecting market trend

input bool UseTakeProfit = true;  // Enable/Disable Take Profit
input double DefaultTP = 100.0;   // Default Take Profit in points

input bool UseStopLoss = true;    // Enable/Disable Stop Loss
input double DefaultSL = 500.0;   // Default Stop Loss in points

input double VolatilityThreshold = 20.0; // ATR threshold for volatility

input bool UseTrailingStop = true;    // Enable/Disable Trailing Stop
input double TrailingStopPoints = 50; // Trailing Stop in points

input bool DebugMode = false;         // Enable/Disable detailed logging

//--- Global variables
double gridLevels[];
int ordersCount = 0;
string successLogFile = "GridMasterPro_success_log.txt";
string errorLogFile = "GridMasterPro_error_log.txt";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    //--- Initialize grid levels array size
    ArrayResize(gridLevels, MaxOrders);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Ensure the grid levels array is resized if MaxOrders is changed
    if (ArraySize(gridLevels) != MaxOrders) {
        ArrayResize(gridLevels, MaxOrders);
    }

    double lastPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double gridDistance = CalculateDynamicGridDistance();

    double tp = 0, sl = 0;

    // Check existing positions and adjust the trailing stop
    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionSelect(_Symbol)) {
            ulong ticket = PositionGetInteger(POSITION_TICKET);  // Retrieve the correct ticket number
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);  // Getting open price
            DetermineTPAndSL(tp, sl, lastPrice, openPrice);
            if (PositionGetDouble(POSITION_SL) != sl) {  // Checking stop loss
                ModifyOrder(ticket, openPrice, sl, tp);
            }
        } else {
            // Handle position selection failure
            Print("Failed to select position for symbol: ", _Symbol);
        }
    }

    // Place the first order
    if (ordersCount == 0) {
        gridLevels[0] = lastPrice;
        if (OpenOrder(ORDER_TYPE_BUY, LotSize, lastPrice, sl, tp)) {
            ordersCount++;
        }
    }

    // Place grid orders
    for (int i = 0; i < ordersCount && i < MaxOrders; i++) {
        if (lastPrice > gridLevels[i] + gridDistance * _Point) {
            gridLevels[i + 1] = lastPrice;
            if (OpenOrder(ORDER_TYPE_BUY, LotSize, lastPrice, sl, tp)) {
                ordersCount++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate dynamic grid distance                                  |
//+------------------------------------------------------------------+
double CalculateDynamicGridDistance() {
    double atr = iATR(_Symbol, 0, ATRPeriod);
    return atr * ATRMultiplier;
}

//+------------------------------------------------------------------+
//| Determine Take Profit and Stop Loss                              |
//+------------------------------------------------------------------+
void DetermineTPAndSL(double& tp, double& sl, double lastPrice, double openPrice) {
    tp = 0;
    if (UseTakeProfit) {
        tp = lastPrice + DefaultTP * _Point;
    }

    if (UseStopLoss) {
        if (UseTrailingStop) {
            double newSL = lastPrice - TrailingStopPoints * _Point;
            sl = MathMax(sl, newSL); // Ensures SL only moves closer to the current price
        } else {
            sl = openPrice - DefaultSL * _Point;
        }
    }
}

//+------------------------------------------------------------------+
//| Open an order                                                    |
//+------------------------------------------------------------------+
bool OpenOrder(ENUM_ORDER_TYPE orderType, double lotSize, double price, double sl, double tp) {
    long tradeAllowed;
    if (!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE, tradeAllowed) || tradeAllowed != SYMBOL_TRADE_MODE_FULL) {
        string errorMsg = "Trading not allowed for symbol: " + _Symbol;
        Print(errorMsg);
        WriteLog(errorLogFile, errorMsg, true);
        return false;
    }

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    if (bid == 0.0 || ask == 0.0) {
        string errorMsg = "No prices available for symbol: " + _Symbol;
        Print(errorMsg);
        WriteLog(errorLogFile, errorMsg, true);
        return false;
    }

    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);

    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = orderType;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 50;
    request.magic = GenerateMagicNumber();
    request.comment = "Grid Order";
    request.type_filling = ORDER_FILLING_IOC;

    const int maxRetries = 5;
    int retries = 0;
    int waitTime = 2000;  // Initial wait time (ms)

    while (retries < maxRetries) {
        if (OrderSend(request, result)) {
            WriteLog(successLogFile, "Order placed successfully. Order ticket: " + IntegerToString(result.order), true);
            return true;
        } else {
            int errorCode = GetLastError();
            string errorMsg = "Order placement failed. Error code: " + IntegerToString(errorCode) + ". " + ErrorDescription(errorCode);
            Print(errorMsg);
            WriteLog(errorLogFile, errorMsg, true);

            retries++;
            waitTime = waitTime * 2 + (MathRand() % 1000);  // Exponential backoff with jitter
            Sleep(waitTime);
        }
    }

    string errorMsg = "Order placement failed after " + IntegerToString(maxRetries) + " retries.";
    Print(errorMsg);
    WriteLog(errorLogFile, errorMsg, true);

    return false;
}

//+------------------------------------------------------------------+
//| Modify an order                                                  |
//+------------------------------------------------------------------+
bool ModifyOrder(ulong ticket, double price, double sl, double tp) {
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);

    request.action = TRADE_ACTION_SLTP;
    request.symbol = _Symbol;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 50;
    request.order = ticket;

    if (OrderSend(request, result)) {
        WriteLog(successLogFile, "Order modified successfully. Order ticket: " + IntegerToString(ticket));
        return true;
    } else {
        int errorCode = GetLastError();
        string errorMsg = "Order modification failed. Error code: " + IntegerToString(errorCode) + ". " + ErrorDescription(errorCode);
        Print(errorMsg);
        WriteLog(errorLogFile, errorMsg);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Generate a unique magic number                                   |
//+------------------------------------------------------------------+
int GenerateMagicNumber() {
    // Ensure _Symbol is not empty
    if (StringLen(_Symbol) < 6) {
        Print("Error: Symbol name too short");
        return -1; // or another error code
    }

    // Generate a unique magic number using the ASCII values of the symbol characters
    long symbolHash = 0;
    for (int i = 0; i < StringLen(_Symbol); i++) {
        symbolHash += StringToInteger(StringSubstr(_Symbol, i, 1));
    }

    long tempMagicNumber = symbolHash + TimeLocal() % 1000;

    // Safely convert to int, ensuring no overflow
    if (tempMagicNumber > INT_MAX) {
        Print("Warning: Magic number exceeds int range, adjusting to INT_MAX...");
        return INT_MAX;
    }

    return (int)tempMagicNumber;
}

//+------------------------------------------------------------------+
//| Write to log file                                                |
//+------------------------------------------------------------------+
void WriteLog(string logFile, string message, bool forceLog = false) {
    if (!DebugMode && !forceLog) return;  // Skip logging unless in debug mode or forced

    int handle = FileOpen(logFile, FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE);
    if (handle != INVALID_HANDLE) {
        // Move the file pointer to the end for appending
        FileSeek(handle, 0, SEEK_END);
        FileWrite(handle, "[" + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + "] " + message);
        FileClose(handle);
    } else {
        Print("Failed to open log file: " + logFile);
    }
}

//+------------------------------------------------------------------+
//| Error description                                                |
//+------------------------------------------------------------------+
string ErrorDescription(int error_code) {
    switch (error_code) {
    case 0: return "No error";
    case 1: return "No error returned, but the result is unknown";
    case 2: return "Common error";
    case 3: return "Invalid trade parameters";
    case 4: return "Trade server is busy";
    case 5: return "Old version of the client terminal";
    case 6: return "No connection with trade server";
    case 7: return "Not enough rights";
    case 8: return "Too frequent requests";
    case 9: return "Malfunctional trade operation";
    case 10: return "Invalid function pointer";
    case 11: return "DLL calls are not allowed";
    case 12: return "Application is busy";
    case 64: return "Account disabled";
    case 65: return "Invalid account";
    case 128: return "Trade timeout";
    case 129: return "Invalid price";
    case 130: return "Invalid stops";
    case 131: return "Invalid trade volume";
    case 132: return "Market is closed";
    case 133: return "Trade is disabled";
    case 134: return "Not enough money";
    case 135: return "Price changed";
    case 136: return "Off quotes";
    case 137: return "Broker is busy";
    case 138: return "Requote";
    case 139: return "Order is locked";
    case 140: return "Long positions only allowed";
    case 141: return "Too many requests";
    case 145: return "Modification denied because order is too close to market";
    case 146: return "Invalid price";
    case 147: return "Stop loss or take profit must be positive";
    case 148: return "Invalid lot size";
    case 149: return "Invalid trade parameters";
    case 150: return "Trade server is busy";
    case 151: return "Old version of the client terminal";
    case 152: return "No connection with trade server";
    case 153: return "Trade timeout";
    case 154: return "Invalid stops";
    case 155: return "Invalid trade volume";
    case 156: return "Market is closed";
    case 157: return "Trade is disabled";
    case 158: return "Not enough money";
    case 159: return "Price changed";
    case 160: return "Off quotes";
    case 161: return "Broker is busy";
    case 162: return "Requote";
    case 163: return "Order is locked";
    case 164: return "Long positions only allowed";
    case 165: return "Too many requests";
    case 4014: return "Error in the generated code";
    default: return "Unknown error";
    }
}
