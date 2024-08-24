//+------------------------------------------------------------------+
//|                                               GridMaster Pro.mq5 |
//|                                           Copyright 2024, Sajid. |
//|                    https://www.mql5.com/en/users/sajidmahamud835 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Sajid."
#property link      "https://www.mql5.com/en/users/sajidmahamud835"
#property version   "1.04"
#property strict

//--- Input Parameters
input double LotSize = 0.1;                 // Lot size for each order
input int MaxOrders = 10;                   // Maximum number of orders in the grid
input int ATRPeriod = 14;                   // ATR period for dynamic grid adjustment
input double ATRMultiplier = 1.5;           // Multiplier for ATR to calculate grid distance
input int TrendPeriod = 50;                 // Period for detecting market trend

input bool UseTakeProfit = true;            // Enable/Disable Take Profit
input double DefaultTP = 100.0;             // Default Take Profit in points

input bool UseStopLoss = true;              // Enable/Disable Stop Loss
input double DefaultSL = 500.0;             // Default Stop Loss in points

input double VolatilityThreshold = 20.0;    // ATR threshold for volatility

input bool UseTrailingStop = true;          // Enable/Disable Trailing Stop
input double TrailingStopPoints = 50;       // Trailing Stop in points

input bool DebugMode = false;               // Enable/Disable Debug Mode

//--- Global Variables
double gridLevels[];                        // Array to store grid levels
int ordersCount = 0;                        // Counter for the number of orders placed
string successLogFile = "GridMasterPro_success_log.txt"; // Log file for successful actions
string errorLogFile = "GridMasterPro_error_log.txt";     // Log file for errors

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    ArrayResize(gridLevels, MaxOrders);     // Resize grid levels array to the maximum number of orders
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Ensure the gridLevels array is correctly sized
    if (ArraySize(gridLevels) != MaxOrders) {
        ArrayResize(gridLevels, MaxOrders);
    }

    double lastPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Current market price
    double gridDistance = CalculateDynamicGridDistance();     // Calculate dynamic grid distance
    double tp = EMPTY_VALUE, sl = EMPTY_VALUE;                // Initialize Take Profit and Stop Loss variables

    // Modify existing orders' SL and TP if necessary
    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionSelect(_Symbol)) {
            ulong ticket = PositionGetInteger(POSITION_TICKET); // Get the position ticket
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN); // Get the open price of the position
            DetermineTPAndSL(tp, sl, lastPrice, openPrice); // Determine Take Profit and Stop Loss levels
            
            // Modify the order if the Stop Loss has changed
            if (PositionGetDouble(POSITION_SL) != sl) {
                ModifyOrder(ticket, openPrice, sl, tp);
            }
        } else {
            Print("Failed to select position for symbol: ", _Symbol);
            break;
        }
    }

    // If no orders are placed yet, open the first order
    if (ordersCount == 0) {
        gridLevels[0] = lastPrice; // Set the first grid level at the current price
        if (OpenOrder(ORDER_TYPE_BUY, LotSize, lastPrice, sl, tp)) {
            ordersCount++;
        }
    }

    // Check if new orders should be placed based on grid distance
    for (int i = 0; i < ordersCount && i < MaxOrders - 1; i++) {
        if (lastPrice > gridLevels[i] + gridDistance * _Point) {
            gridLevels[i + 1] = lastPrice; // Set the next grid level
            if (OpenOrder(ORDER_TYPE_BUY, LotSize, lastPrice, sl, tp)) {
                ordersCount++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate dynamic grid distance based on ATR                     |
//+------------------------------------------------------------------+
double CalculateDynamicGridDistance() {
    double atr = iATR(_Symbol, 0, ATRPeriod); // Get ATR value
    return atr * ATRMultiplier;              // Calculate grid distance
}

//+------------------------------------------------------------------+
//| Determine Take Profit and Stop Loss levels                       |
//+------------------------------------------------------------------+
void DetermineTPAndSL(double& tp, double& sl, double lastPrice, double openPrice) {
    tp = EMPTY_VALUE;
    sl = EMPTY_VALUE;

    if (UseTakeProfit) {
        tp = lastPrice + DefaultTP * _Point; // Calculate Take Profit level
    }

    if (UseStopLoss) {
        if (UseTrailingStop) {
            double newSL = lastPrice - TrailingStopPoints * _Point; // Calculate Trailing Stop level
            sl = MathMax(sl, newSL); // Set Stop Loss to the maximum of the existing or new SL
        } else {
            sl = openPrice - DefaultSL * _Point; // Set Stop Loss based on the default value
        }
    }
}

//+------------------------------------------------------------------+
//| Open a new order                                                  |
//+------------------------------------------------------------------+
bool OpenOrder(ENUM_ORDER_TYPE orderType, double lotSize, double price, double sl, double tp) {
    long tradeAllowed;
    // Check if trading is allowed for the symbol
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

    // Fill the trade request
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

    // Retry mechanism for order placement
    const int maxRetries = 5;
    int retries = 0;
    int waitTime = 2000;

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
            waitTime = waitTime * 2 + (MathRand() % 1000); // Exponential backoff with some randomness
            Sleep(waitTime);
        }
    }

    // Log final failure after exhausting retries
    string finalErrorMsg = "Order placement failed after " + IntegerToString(maxRetries) + " retries.";
    Print(finalErrorMsg);
    WriteLog(errorLogFile, finalErrorMsg, true);

    return false;
}

//+------------------------------------------------------------------+
//| Modify an existing order's SL/TP                                 |
//+------------------------------------------------------------------+
bool ModifyOrder(ulong ticket, double price, double sl, double tp) {
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);

    // Fill the modification request
    request.action = TRADE_ACTION_SLTP;
    request.symbol = _Symbol;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 50;
    request.order = ticket;

    // Send the modification request
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
//| Generate a magic number for orders                               |
//+------------------------------------------------------------------+
int GenerateMagicNumber() {
    if (StringLen(_Symbol) < 6) {
        Print("Error: Symbol name too short");
        return -1;
    }

    long symbolHash = 0;
    for (int i = 0; i < StringLen(_Symbol); i++) {
        symbolHash += StringToInteger(StringSubstr(_Symbol, i, 1)) * i;
    }

    return int(symbolHash) % 10000; // Return a 4-digit magic number
}

//+------------------------------------------------------------------+
//| Log function to write messages to a log file                     |
//+------------------------------------------------------------------+
void WriteLog(string filename, string message, bool addTimestamp = false) {
    int handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ';');
    if (handle != INVALID_HANDLE) {
        if (addTimestamp) {
            message = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + " - " + message;
        }
        FileWrite(handle, message);
        FileClose(handle);
    } else {
        Print("Failed to open log file: ", filename);
    }
}

//+------------------------------------------------------------------+
//| Error Description helper function                                |
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode) {
    string errorText;
    switch (errorCode) {
        case 10004: errorText = "Trade is disabled"; break;
        case 10006: errorText = "No connection with trade server"; break;
        case 10007: errorText = "Account is invalid"; break;
        case 10008: errorText = "Common error"; break;
        case 10009: errorText = "Trade server is busy"; break;
        case 10010: errorText = "Old version of the client terminal"; break;
        case 10011: errorText = "Too many requests"; break;
        case 10012: errorText = "Request is too frequently sent"; break;
        case 10013: errorText = "Order send error"; break;
        case 10014: errorText = "Order modify error"; break;
        case 10015: errorText = "Order delete error"; break;
        case 10016: errorText = "Trade context is busy"; break;
        case 10017: errorText = "Trade timeout"; break;
        case 10018: errorText = "Trade is forbidden"; break;
        case 10019: errorText = "Invalid price"; break;
        case 10020: errorText = "Invalid stops"; break;
        case 10021: errorText = "Invalid trade volume"; break;
        case 10022: errorText = "Market is closed"; break;
        default: errorText = "Unknown error"; break;
    }
    return errorText;
}
