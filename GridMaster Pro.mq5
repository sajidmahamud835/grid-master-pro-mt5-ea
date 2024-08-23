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
//--- Global variables
double gridLevels[];
int ordersCount = 0;

//--- Log file paths
string errorLogFile = "GridMasterPro_ErrorLog.txt";
string successLogFile = "GridMasterPro_SuccessLog.txt";
string orderLogFile = "GridMasterPro_OrderLog.txt";

//--- Function to generate a dynamic magic number based on the symbol
int GenerateMagicNumber() {
    return StringToInteger(StringSubstr(_Symbol, 0, 4) + StringSubstr(_Symbol, 4, 2));
}

//+------------------------------------------------------------------+
//| Error description function                                       |
//+------------------------------------------------------------------+
string ErrorDescription(int code) {
    switch (code) {
        case 10004: return "Requote";
        case 10006: return "Request rejected";
        case 10007: return "Request canceled by trader";
        case 10008: return "Order placed";
        case 10009: return "Request completed";
        case 10010: return "Only part of the request was completed";
        case 10011: return "Request processing error";
        case 10012: return "Request canceled by timeout";
        case 10013: return "Invalid request";
        case 10014: return "Invalid volume in the request";
        case 10015: return "Invalid price in the request";
        case 10016: return "Invalid stops in the request";
        case 10017: return "Trade is disabled";
        case 10018: return "Market is closed";
        case 10019: return "Not enough money to complete the request";
        case 10020: return "Prices changed";
        case 10021: return "No quotes to process the request";
        case 10022: return "Invalid order expiration date";
        case 10023: return "Order state changed";
        case 10024: return "Too frequent requests";
        case 10025: return "No changes in request";
        case 10026: return "Autotrading disabled by server";
        case 10027: return "Autotrading disabled by client terminal";
        case 10028: return "Request locked for processing";
        case 10029: return "Order or position frozen";
        case 10030: return "Invalid order filling type";
        case 10031: return "No connection with the trade server";
        case 10032: return "Operation allowed only for live accounts";
        case 10033: return "Pending orders limit reached";
        case 10034: return "Volume of orders/positions for the symbol limit reached";
        case 10035: return "Incorrect or prohibited order type";
        case 10036: return "Position with specified POSITION_IDENTIFIER already closed";
        case 10038: return "Close volume exceeds current position volume";
        case 10039: return "Close order already exists for specified position";
        case 10040: return "Open positions limit on account reached by server settings";
        case 10041: return "Pending order activation rejected, order canceled";
        case 10042: return "Rejected: 'Only long positions allowed' rule for symbol";
        case 10043: return "Rejected: 'Only short positions allowed' rule for symbol";
        case 10044: return "Rejected: 'Only position closing allowed' rule for symbol";
        case 10045: return "Rejected: 'Position closing allowed only by FIFO rule'";
        case 10046: return "Rejected: 'Opposite positions disabled' rule for account";
        default:    return "Unknown error";
    }
}

//+------------------------------------------------------------------+
//| Initialization function                                          |
//+------------------------------------------------------------------+
int OnInit() {
    //--- Initialize grid levels array size
    ArrayResize(gridLevels, MaxOrders);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    //--- Cleanup code if needed
}

//+------------------------------------------------------------------+
//| Function to write logs                                           |
//+------------------------------------------------------------------+
void WriteLog(string logFile, string message) {
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
//| Function to calculate dynamic grid distance                      |
//+------------------------------------------------------------------+
double CalculateDynamicGridDistance() {
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if (atrHandle == INVALID_HANDLE) {
        string errorMsg = "Failed to create ATR handle. Error code: " + IntegerToString(GetLastError());
        Print(errorMsg);
        WriteLog(errorLogFile, errorMsg);
        return 0;
    }

    double atrValue[];
    if (CopyBuffer(atrHandle, 0, 0, 1, atrValue) <= 0) {
        string errorMsg = "Failed to copy ATR values. Error code: " + IntegerToString(GetLastError());
        Print(errorMsg);
        WriteLog(errorLogFile, errorMsg);
        IndicatorRelease(atrHandle);
        return 0;
    }

    IndicatorRelease(atrHandle);
    return atrValue[0] * ATRMultiplier;
}

//+------------------------------------------------------------------+
//| Function to detect market trend                                  |
//+------------------------------------------------------------------+
bool IsMarketTrending()
{
    int maHandle = iMA(_Symbol, PERIOD_CURRENT, TrendPeriod, 0, MODE_SMA, PRICE_CLOSE);
    if (maHandle == INVALID_HANDLE)
    {
        string errorMsg = "Failed to create MA handle. Error code: " + IntegerToString(GetLastError());
        Print(errorMsg);
        WriteLog(errorLogFile, errorMsg);
        return false;
    }

    double maValue[];
    int copied = CopyBuffer(maHandle, 0, 0, 1, maValue);
    if (copied <= 0)
    {
        string errorMsg = "Failed to copy MA values. Error code: " + IntegerToString(GetLastError());
        Print(errorMsg);
        WriteLog(errorLogFile, errorMsg);
        IndicatorRelease(maHandle);
        return false;
    }

    IndicatorRelease(maHandle);
    double lastPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    return (lastPrice > maValue[0] || lastPrice < maValue[0]);
}

//+------------------------------------------------------------------+
//| Function to detect market volatility                             |
//+------------------------------------------------------------------+
bool IsMarketVolatile()
{
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if (atrHandle == INVALID_HANDLE)
    {
        string errorMsg = "Failed to create ATR handle. Error code: " + IntegerToString(GetLastError());
        Print(errorMsg);
        WriteLog(errorLogFile, errorMsg);
        return false;
    }

    double atrValue[];
    int copied = CopyBuffer(atrHandle, 0, 0, 1, atrValue);
    if (copied <= 0)
    {
        string errorMsg = "Failed to copy ATR values. Error code: " + IntegerToString(GetLastError());
        Print(errorMsg);
        WriteLog(errorLogFile, errorMsg);
        IndicatorRelease(atrHandle);
        return false;
    }

    IndicatorRelease(atrHandle);
    return (atrValue[0] > VolatilityThreshold * _Point);
}


//+------------------------------------------------------------------+
//| Function to determine take profit and stop loss                  |
//+------------------------------------------------------------------+
void DetermineTPAndSL(double& tp, double& sl, double lastPrice) {
    tp = 0;
    if (UseTakeProfit) {
        tp = lastPrice + DefaultTP * _Point;
    }

    sl = 0;
    if (UseStopLoss) {
        sl = lastPrice - DefaultSL * _Point;
    }
}

//+------------------------------------------------------------------+
//| Tick function                                                    |
//+------------------------------------------------------------------+
void OnTick() {
    double lastPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double gridDistance = CalculateDynamicGridDistance();

    double tp, sl;
    DetermineTPAndSL(tp, sl, lastPrice);

    //--- Place the first order
    if (ordersCount == 0) {
        gridLevels[0] = lastPrice;
        if (OpenOrder(ORDER_TYPE_BUY, LotSize, lastPrice, sl, tp)) {
            ordersCount++;
        }
    }

    //--- Place grid orders
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
//| Function to open an order                                        |
//+------------------------------------------------------------------+
bool OpenOrder(ENUM_ORDER_TYPE orderType, double lotSize, double price, double sl, double tp) {
    long tradeAllowed;
    if (!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE, tradeAllowed) || tradeAllowed != SYMBOL_TRADE_MODE_FULL) {
        string errorMsg = "Trading not allowed for symbol: " + _Symbol;
        Print(errorMsg);
        WriteLog(errorLogFile, errorMsg);
        return false;
    }

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    if (bid == 0.0 || ask == 0.0) {
        string errorMsg = "No prices available for symbol: " + _Symbol;
        Print(errorMsg);
        WriteLog(errorLogFile, errorMsg);
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
    int waitTime = 2000;

    while (retries < maxRetries) {
        if (OrderSend(request, result)) {
            WriteLog(successLogFile, "Order placed successfully. Order ticket: " + IntegerToString(result.order));
            return true;
        } else {
            int errorCode = GetLastError();
            string errorMsg = "Order placement failed. Error code: " + IntegerToString(errorCode) + ". " + ErrorDescription(errorCode);
            Print(errorMsg);
            WriteLog(errorLogFile, errorMsg);

            retries++;
            Sleep(waitTime);
        }
    }

    string errorMsg = "Order placement failed after " + IntegerToString(maxRetries) + " retries.";
    Print(errorMsg);
    WriteLog(errorLogFile, errorMsg);

    return false;
}
