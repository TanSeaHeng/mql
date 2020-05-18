//+------------------------------------------------------------------+
//|                                                   HMA RSI EA.mq4 |
//|                              Copyright 2020, CrazyFxTrader. Corp |
//|                                         http://crazyfxtrader.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, CrazyFxTrader. Corp"
#property link      "http://crazyfxtrader.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
datetime ExpiredTime = D'2022.03.10 00:00:00'; // Expired Date
int      AccountNo = 0;               // Account Number


enum ENUM_HMA_OPTION {
   SINGLE_HMA,
   DOUBLE_HMA,
};

enum ENUM_CONTINUE_OR_STOP {
   CONTINUE,
   STOP_UNTIL_RESTART
};

enum ENUM_CLOSE_BY_FAST_HMA {
   NONE,
   YELLOW,
   CHANGED
};

input string P_Trading = "---------- General Trading Section ----------";
input ENUM_HMA_OPTION TradingType = SINGLE_HMA;
input bool ActiveRSIFilter = true; // Active RSI Filter
input bool ActiveRSIClose = true; // Active Close By RSI
input double Lots = 0.01; // Fix Lot Size
input double TakeProfit = 50; // Take Profit Pips
input double StopLoss = 50; // Stop Loss Pips
input ENUM_CONTINUE_OR_STOP ContinueOrStop = CONTINUE;
input ENUM_CLOSE_BY_FAST_HMA CloseByFastHMA = YELLOW;
input int MaxTrades = 5; // Max Concurrent Orders on All Pairs
input int MagicNumber = 2434354;
input string CommentOrder = "HMA RSI EA";

input string P_TraingFilter = "---------- Trailing Section ----------";
input bool   UseTrailStop     = false;          // Activate Trail Stop
input double InpTrailingStart = 20;             // Trailing Start in Pips
input double InpTrailingStop  = 20;            // Trailing Distance in Pips
input double InpTrailingStep  = 10;             // Trailing Step in Pips

input string P_TimeFilter = "---------- Time Filter Section ----------";
input bool TimeFilter = true; // Activate Time Filter
input string TradeStartTime = "3:00"; // GMT TradingStartTime
input string TradeStopTime = "9:00"; // GMT TradingEndTime

input string P_Symbols = "---------- Symbols Section ----------";
input bool MultiSymbols = false; // Activate Multi Symbols
input string Symbols = "GBPUSD, USDCHF, USDJPY, AUDUSD, NZDUSD, USDCAD, EURCHF, EURGBP, EURJPY, GBPJPY,EURUSD";

input string P_HMASection = "---------- HMA Inidcator Section ----------";
input int FastHMAPeriod = 50;
input int SlowHMAPeriod = 80;

input string P_RSISection = "---------- RSI Inidcator Section ----------";
input int RSIPeriod = 14;
input ENUM_APPLIED_PRICE RSIPrice = PRICE_CLOSE;
input double RSIHighLevel = 60;
input double RSILowLevel = 40;

struct ORDER {
   int order_ticket;
   string symbol;
   int fast_hma_trend;
   ENUM_ORDER_TYPE order_type;
   void Set(string sym, ENUM_ORDER_TYPE ord, int order_num, double fast_up, double fast_down)
   {
      order_ticket = order_num;
      symbol = sym;
      order_type = ord;
      if (fast_up == EMPTY_VALUE && fast_down != EMPTY_VALUE) fast_hma_trend = -1;
      else if (fast_up != EMPTY_VALUE && fast_down == EMPTY_VALUE) fast_hma_trend = 1;
      else fast_hma_trend = 0;
   }   
   void Reset(double fast_up, double fast_down)
   {
      if (order_type == OP_BUY && fast_hma_trend == 1) return;
      if (order_type == OP_SELL && fast_hma_trend == -1) return;
      if (fast_up == EMPTY_VALUE && fast_down != EMPTY_VALUE) fast_hma_trend = -1;
      else if (fast_up != EMPTY_VALUE && fast_down == EMPTY_VALUE) fast_hma_trend = 1;
   }
};

string SymbolList[];
bool TradeArray[];

int Slippage = 10;

ORDER Orders[];

int OnInit()
  {
//---
   if (CheckExpired()) return INIT_FAILED;
   if (CheckAccount() == false) return INIT_FAILED;
   
   if (MultiSymbols)
   {
      string symbols;
      if (StringFind(Symbols, Symbol()) < 0)
         symbols = Symbols + "," + Symbol();
      else symbols = Symbols;
      getAvailableCurrencyPairs(SymbolList, symbols);
   }
   else 
   {
      ArrayResize(SymbolList, 1);
      SymbolList[0] = Symbol();
   }
   
   if (ContinueOrStop == STOP_UNTIL_RESTART)
   {
      ArrayResize(TradeArray, ArraySize(SymbolList));
      for (int i = 0; i < ArraySize(TradeArray); i++)
         TradeArray[i] = False;
   }
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   if (ContinueOrStop == STOP_UNTIL_RESTART)
      ArrayFree(TradeArray);
   ArrayFree(SymbolList);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   TrailStop(InpTrailingStop, InpTrailingStep, InpTrailingStart);
   CheckOrder();
   CloseByRSI();
   if (!TimeFiltering()) return;
   EntryOrder();
  }
//+------------------------------------------------------------------+



bool CheckExpired()
{
   if (ExpiredTime < TimeCurrent())
   {
      Alert("Your account was already Expired.");
      return true;
   }
   return false;
}

bool CheckAccount()
{
   if (AccountNo == 0) return true;
   if (AccountInfoInteger(ACCOUNT_LOGIN) != AccountNo) 
   {
      Alert("Your account was not Registered.");
      return false;
   }
   return true;
}


int getAvailableCurrencyPairs(string& availableCurrencyPairs[], string symbolText = "")
{
//---   
   bool selected = false;
   const int symbolsCount = SymbolsTotal(selected);
   int currencypairsCount;
   ArrayResize(availableCurrencyPairs, symbolsCount);
   int idxCurrencyPair = 0;
   string symbolList = symbolText + ",";
   
   for(int idxSymbol = 0; idxSymbol < symbolsCount; idxSymbol++)
   {      
      string symbol = SymbolName(idxSymbol, selected);
      if (StringLen(symbol) <= 1) continue;
      symbol = symbol + ",";
      int result = StringFind(symbolList, symbol);
      if (result == -1) continue;
      
      symbol = StringSubstr(symbol, 0, StringLen(symbol) - 1);
      //if(firstChar != "#" && StringLen(symbol) == 6)
      {        
         availableCurrencyPairs[idxCurrencyPair++] = symbol; 
      }
   }
   currencypairsCount = idxCurrencyPair;
   ArrayResize(availableCurrencyPairs, currencypairsCount);
   return currencypairsCount;
}


//+------------------------------------------------------------------+
//| Trailing Stop function                                           |
//+------------------------------------------------------------------+
void TrailStop(double dist=20.0, double step=1.0, double start=0) {

   if (!UseTrailStop) return;
   
   double sl_new=0;
   double osl=0;
   double oop=0;
   
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == false) continue;
      if(OrderMagicNumber()!= MagicNumber) continue;
      double _bid = SymbolInfoDouble(OrderSymbol(), SYMBOL_BID);
      double _ask = SymbolInfoDouble(OrderSymbol(), SYMBOL_ASK);
      double pipSize = GetPipSize(OrderSymbol());
      int digits = (int)SymbolInfoInteger(OrderSymbol(), SYMBOL_DIGITS);

      osl=OrderStopLoss();
      oop=OrderOpenPrice();
      //if (osl == 0) continue;
      if(OrderType()==OP_BUY) {
         if (_bid > oop + start*pipSize) {
            if (_bid > osl + (dist+step)*pipSize) {
               sl_new=ND(_bid-dist*pipSize, digits);
               if (!OrderModify(OrderTicket(),OrderOpenPrice(),sl_new,OrderTakeProfit(),0,clrNONE)) {
                  Print("   ***   TS Order BUY Modify Error. OOP="+DTS(OrderOpenPrice(), digits)+", SL="+DTS(sl_new, digits)+
                        ", TP="+DTS(OrderTakeProfit(), digits));
               }
               else Print("   ***   TrailStop Order BUY Modify. Ticket#"+(string)OrderTicket()+" OrderOpenPrice="+DTS(OrderOpenPrice(), digits)+
                          ", SL="+DTS(sl_new, digits)+", TP="+DTS(OrderTakeProfit(), digits));
            }
         }
      }
      if(OrderType()==OP_SELL) {
         if (_ask < oop - start*pipSize) {
            if (_ask < osl - (dist+step)*pipSize || MathAbs(osl) < 1e-6) {
               sl_new=ND(_ask+dist*pipSize, digits);
               if (!OrderModify(OrderTicket(),OrderOpenPrice(),sl_new,OrderTakeProfit(),0,clrNONE)) {
                  Print("   ***   TS Order SELL Modify Error. OOP="+DTS(OrderOpenPrice(), digits)+", SL="+DTS(sl_new, digits)+
                        ", TP="+DTS(OrderTakeProfit(), digits));
               }
               else Print("   ***   TrailStop Order SELL Modify. Ticket#"+(string)OrderTicket()+" OrderOpenPrice="+DTS(OrderOpenPrice(), digits)+
                          ", SL="+DTS(sl_new, digits)+", TP="+DTS(OrderTakeProfit(), digits));
            }
         }
      }
   }
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Normalize Double Custom function                                 |
//+------------------------------------------------------------------+
double ND(double v, int dg)  {
    return(NormalizeDouble(v,dg));
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Double to String Custom function                                 |
//+------------------------------------------------------------------+
string DTS(double value, int dg) {
  return(DoubleToString(value,dg));
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|  Normalize Lot Function                                          |
//+------------------------------------------------------------------+
double NormalizeLot(double lo, bool ro=false, string sy="") {
  double lot, k;
  if (sy=="" || sy=="0") sy=_Symbol;
  double ls=SymbolInfoDouble(sy, SYMBOL_VOLUME_STEP);
  double ml=SymbolInfoDouble(sy, SYMBOL_VOLUME_MIN);
  double mx=SymbolInfoDouble(sy, SYMBOL_VOLUME_MAX);

  if (ml==0) ml=0.1;
  if (mx==0) mx=100;

  if (ls>0) k=1/ls; else k=1/ml;
  if (ro) lot=MathCeil(lo*k)/k; 
  else    lot=MathFloor(lo*k)/k;

  if (lot<ml) lot=ml;
  if (lot>mx) lot=mx;

  return(lot);
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Correct Price function                                           |
//+------------------------------------------------------------------+
double CorrectPrice (const string Symb, const double Price) {

  const double TickSize = MathMax(SymbolInfoDouble(Symb, SYMBOL_TRADE_TICK_SIZE), SymbolInfoDouble(Symb, SYMBOL_POINT));
  
  return(NormalizeDouble(((int)(Price / TickSize + 0.1)) * TickSize, (int)SymbolInfoInteger(Symb, SYMBOL_DIGITS)));
}
//+------------------------------------------------------------------+


double GetPipSize(string symbol)
{
   double PipSize = MarketInfo(symbol, MODE_POINT);
   int pairdigits = (int)MarketInfo(symbol, MODE_DIGITS);
   if(pairdigits == 3 || pairdigits == 5) PipSize = PipSize * 10.0;
   if (PipSize == 0) PipSize = 1;
   if (StringFind(symbol,"XAUUSD") >= 0) PipSize = PipSize * 100;
   return PipSize;
}


int GetOrdersCount(string symbol="", int orderType = -1)
{
   int orders = OrdersTotal();
   int result = 0;
   string sym;
   sym = symbol;
   for (int i = orders - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS) == false) continue;
      if (symbol == "") sym = OrderSymbol();
      if(OrderSymbol() != sym || OrderMagicNumber()!= MagicNumber) continue;
      if (orderType == -1)
         result++;
      else if (orderType == OrderType())
         result++;
   }
   return result;
}


bool PositionClose(int orderTicket, int slippage)
{
   if (!OrderSelect(orderTicket, SELECT_BY_TICKET)) return false;
   double bid = SymbolInfoDouble(OrderSymbol(), SYMBOL_BID);
   double ask = SymbolInfoDouble(OrderSymbol(), SYMBOL_ASK);
   bool isSuccess = false;
   if (OrderType() == OP_BUY)
   {
      isSuccess = OrderClose(OrderTicket(), OrderLots(), bid, slippage, clrGreen);
   }
   else if (OrderType() == OP_SELL)
   {
      isSuccess = OrderClose(OrderTicket(), OrderLots(), ask, slippage, clrRed);
   }
   return isSuccess;
}


void CloseAllOrders()
{
   int size = OrdersTotal();
   for (int i = size - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS)) continue;
      if (OrderMagicNumber() != MagicNumber) continue;
      PositionClose(OrderTicket(), Slippage);
   }
}


bool TimeFiltering()
{
   if (!TimeFilter) return true;
   datetime current = TimeGMT();
   string currstr = TimeToString(current, TIME_DATE);
   string startTime = currstr + " " + TradeStartTime;
   string stopTime = currstr + " " + TradeStopTime;
   datetime begin = StrToTime(startTime);
   datetime end = StrToTime(stopTime);
   if (begin >= end) begin = begin - 24 * 3600;
   bool EAActivated = (current>begin && current<end);  
   return EAActivated;
}

bool OpenNewOrder(string symbol, int OrdType, double lot, double sl, double tp, int &OrderTicketNum)
{
   double PipSize = GetPipSize(symbol);
   double ask, bid;
   double d_sl=0, d_tp=0;
   ask = MarketInfo(symbol, MODE_ASK);
   bid = MarketInfo(symbol, MODE_BID);
   double stoploss, takeprofit;
   double lots = NormalizeLot(lot, false, symbol);
   int digits = (int)MarketInfo(symbol, MODE_DIGITS);
   bool isSuccess;
   if (OrdType == OP_BUY)
   {
      OrderTicketNum = OrderSend(symbol, OP_BUY, lots, ask, Slippage, 0, 0, CommentOrder, MagicNumber, 0, clrGreen);
      if (OrderTicketNum < 0) return false; //failed to enter order
      
      stoploss = GetStopLoss(symbol, OrdType, ask, PipSize, sl);
      if (!UseTrailStop)
         takeprofit = GetTakeProfit(symbol, OrdType, ask, PipSize, tp);
      else takeprofit = 0;
      
      if (stoploss != 0 || takeprofit != 0)
      {
         if (!OrderSelect(OrderTicketNum, SELECT_BY_TICKET)) return false;
         if (stoploss != 0)
         {
            d_sl=CorrectPrice(symbol,stoploss); d_sl=(d_sl>=bid)?CorrectPrice(symbol,bid-3.0*PipSize):d_sl; 
         }
         else d_sl = 0;
         if (takeprofit != 0)
         {
            d_tp=CorrectPrice(symbol,takeprofit);d_tp=(d_tp<=ask)?CorrectPrice(symbol,ask+3.0*PipSize):d_tp;
         }
         else d_tp = 0;
         //Alert("tp:" + d_tp + " takeprofit:" + takeprofit + " sl:" + d_sl + " stoploss:" + stoploss);
         isSuccess = OrderModify(OrderTicket(), OrderOpenPrice(), d_sl, d_tp, 0, clrGreen);
         if(!isSuccess) 
            Print("Error in OrderModify. Error code=",GetLastError()); 
         else 
            Print("Order modified successfully.");
      }
      //if (getme_result == 0)
      //   bot.SendMessage(InpChannelId, "a=buy c=" + symbol + " s=" + DoubleToString(stoploss, digits) +
      //                  " t=" + DoubleToString(takeprofit, digits) + " r=" + IntegerToString(TrailingStop) + " m="  + IntegerToString(OrderTicketNum));
   }
   else if (OrdType == OP_SELL)
   {
      OrderTicketNum = OrderSend(symbol, OP_SELL, lots, bid, Slippage, 0, 0, CommentOrder, MagicNumber, 0, clrRed);
      if (OrderTicketNum < 0) return false; //failed to enter order
      stoploss = GetStopLoss(symbol, OrdType, bid, PipSize, sl);
      if (!UseTrailStop)
         takeprofit = GetTakeProfit(symbol, OrdType, bid, PipSize, tp);
      else takeprofit = 0;
      
      if (stoploss != 0 || takeprofit != 0)
      {
         if (!OrderSelect(OrderTicketNum, SELECT_BY_TICKET)) return false;
         if (takeprofit != 0)
         {
            d_tp=CorrectPrice(symbol,takeprofit); d_tp=(d_tp>=bid)?CorrectPrice(symbol,bid-3.0*PipSize):d_tp;
         }
         else d_tp = 0;
         if (stoploss != 0)
         {
            d_sl=CorrectPrice(symbol,stoploss); d_sl=(d_sl<=ask)?CorrectPrice(symbol,ask+3.0*PipSize):d_sl; 
         }
         else d_sl = 0;
            
         //Alert("tp:" + d_tp + " takeprofit:" + takeprofit + " sl:" + d_sl + " stoploss:" + stoploss);
         isSuccess = OrderModify(OrderTicket(), OrderOpenPrice(), d_sl, d_tp, 0, clrRed);
         if(!isSuccess) 
            Print("Error in OrderModify. Error code=",GetLastError()); 
         else 
            Print("Order modified successfully."); 
      }
      //if (getme_result == 0)
      //   bot.SendMessage(InpChannelId, "a=sell c=" + symbol + " s=" + DoubleToString(stoploss, digits) +
      //                  " t=" + DoubleToString(takeprofit, digits) + " r=" + IntegerToString(TrailingStop) + " m="  + IntegerToString(OrderTicketNum));
   }
   else return false;
   return true;
}


double GetStopLoss(string symbol, int ot, double op=0, double ps = 1, double fix=1)
{
   if (fix == 0) return 0;
   if (ot == OP_BUY)
      return op - fix * ps;
   else if (ot == OP_SELL)
      return op + fix * ps;
   else return 0;
   return 0;
}

double GetTakeProfit(string symbol, int ot, double op, double ps, double fix)
{
   if (fix == 0) return 0;
   if (ot == OP_BUY)
      return op + fix * ps;
   else if (ot == OP_SELL)
      return op - fix * ps;
   else return 0;
   return 0;
}


void EntryOrder()
{
   double fast_hma, fast_hma_up, fast_hma_down, fast_hma_pre_down, fast_hma_pre_up;
   double slow_hma;
   double rsi;
   double open, close;
   for (int i = 0; i < ArraySize(SymbolList); i++)
   {
      if (GetOrdersCount() >= MaxTrades) return;
      if (GetOrdersCount(SymbolList[i]) > 0) continue;
      if (ContinueOrStop == STOP_UNTIL_RESTART)
      {
         if (TradeArray[i]) continue;
      }
      
      open = iOpen(SymbolList[i], Period(), 1);
      close = iClose(SymbolList[i], Period(), 1);
      int OrderNum = -1;
      bool result = false;
      ENUM_ORDER_TYPE ordType;
      if (TradingType == DOUBLE_HMA)
      {
         fast_hma = iCustom(SymbolList[i], Period(), "HMA_v2", 0, FastHMAPeriod, 0, 1);
         slow_hma = iCustom(SymbolList[i], Period(), "HMA_v2", 0, SlowHMAPeriod, 0, 1);
         if (ActiveRSIFilter)
         {
            rsi = iRSI(SymbolList[i], Period(), RSIPeriod, RSIPrice, 1);
            if (rsi > RSILowLevel && rsi < RSIHighLevel) continue;
            if (open > fast_hma && open > slow_hma && close < fast_hma && close < slow_hma)
            {
               if (rsi > RSILowLevel) continue;
               ordType = OP_SELL;
               result = OpenNewOrder(SymbolList[i], OP_SELL, Lots, StopLoss, TakeProfit, OrderNum);
            }
            else if (open < fast_hma && open < slow_hma && close > fast_hma && close > slow_hma)
            {
               if (rsi < RSIHighLevel) continue;
               ordType = OP_BUY;
               result = OpenNewOrder(SymbolList[i], OP_BUY, Lots, StopLoss, TakeProfit, OrderNum);
            }
            else continue;
         }
         else
         {
            if (open > fast_hma && open > slow_hma && close < fast_hma && close < slow_hma)
            {
               ordType = OP_SELL;
               result = OpenNewOrder(SymbolList[i], OP_SELL, Lots, StopLoss, TakeProfit, OrderNum);
            }
            else if (open < fast_hma && open < slow_hma && close > fast_hma && close > slow_hma)
            {
               ordType = OP_BUY;
               result = OpenNewOrder(SymbolList[i], OP_BUY, Lots, StopLoss, TakeProfit, OrderNum);
            }
            else continue;
         }
      }
      else if (TradingType == SINGLE_HMA)
      {
         fast_hma_up = iCustom(SymbolList[i], Period(), "HMA_v2", 0, FastHMAPeriod, 0.0, 1, 0, 1, 1);
         fast_hma_pre_down = iCustom(SymbolList[i], Period(), "HMA_v2", 0, FastHMAPeriod, 0.0, 1, 0, 2, 2);
         fast_hma_down = iCustom(SymbolList[i], Period(), "HMA_v2", 0, FastHMAPeriod, 0.0, 1, 0, 2, 1);
         fast_hma_pre_up = iCustom(SymbolList[i], Period(), "HMA_v2", 0, FastHMAPeriod, 0.0, 1, 0, 1, 2);
         if (ActiveRSIFilter)
         {
            rsi = iRSI(SymbolList[i], Period(), RSIPeriod, RSIPrice, 1);
            if (rsi > RSILowLevel && rsi < RSIHighLevel) continue;
            if (rsi < RSILowLevel && fast_hma_down != EMPTY_VALUE)
            {
               ordType = OP_SELL;
               result = OpenNewOrder(SymbolList[i], OP_SELL, Lots, StopLoss, TakeProfit, OrderNum);
            }
            else if (rsi > RSIHighLevel && fast_hma_up != EMPTY_VALUE)   
            {
               ordType = OP_BUY;
               result = OpenNewOrder(SymbolList[i], OP_BUY, Lots, StopLoss, TakeProfit, OrderNum);
            }
            else continue;
         }
         else
         {
            if (fast_hma_down != EMPTY_VALUE && fast_hma_pre_down == EMPTY_VALUE)
            {
               ordType = OP_SELL;
               result = OpenNewOrder(SymbolList[i], OP_SELL, Lots, StopLoss, TakeProfit, OrderNum);
            }
            else if (fast_hma_up != EMPTY_VALUE && fast_hma_pre_up == EMPTY_VALUE)
            {
               ordType = OP_BUY;
               result = OpenNewOrder(SymbolList[i], OP_BUY, Lots, StopLoss, TakeProfit, OrderNum);
            }
            else continue;
         }
      }
      else continue;
      if (OrderNum < 0) continue;
      if (CloseByFastHMA != NONE && TradingType == DOUBLE_HMA)
      {
         fast_hma_down = iCustom(SymbolList[i], Period(), "HMA_v2", 0, FastHMAPeriod, 0.0, 1, 0, 2, 1);
         fast_hma_up = iCustom(SymbolList[i], Period(), "HMA_v2", 0, FastHMAPeriod, 0.0, 1, 0, 1, 1);
         AddOrder(SymbolList[i], ordType, OrderNum, fast_hma_up, fast_hma_down);
      }
      if (ContinueOrStop == STOP_UNTIL_RESTART)
         TradeArray[i] = True;
   }
}

void AddOrder(string symbol, ENUM_ORDER_TYPE ord, int ordNum, double up, double down)
{
   int size = ArraySize(Orders);
   ArrayResize(Orders, size + 1);
   Orders[size].Set(symbol, ord, ordNum, up, down);
}

void CheckOrder()
{
   if (CloseByFastHMA == NONE) 
   {
      ArrayFree(Orders);
      return;
   }
   if (TradingType == SINGLE_HMA)
   {
      int counts = OrdersTotal();
      for (int i = counts - 1; i >= 0; i--)
      {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if (MagicNumber != OrderMagicNumber()) continue;
         
         double fast_down = iCustom(OrderSymbol(), Period(), "HMA_v2", 0, FastHMAPeriod, 0.0, 1, 0, 2, 1);
         double fast_up = iCustom(OrderSymbol(), Period(), "HMA_v2", 0, FastHMAPeriod, 0.0, 1, 0, 1, 1);
         if (CloseByFastHMA == CHANGED)
         {
            if (OrderType() == OP_BUY && fast_down != EMPTY_VALUE) PositionClose(OrderTicket(), Slippage);
            else if (OrderType() == OP_SELL && fast_up != EMPTY_VALUE) PositionClose(OrderTicket(), Slippage);
         }
         else if (CloseByFastHMA == YELLOW)
         {
            if (OrderType() == OP_BUY && fast_up == EMPTY_VALUE) PositionClose(OrderTicket(), Slippage);
            else if (OrderType() == OP_SELL && fast_down == EMPTY_VALUE) PositionClose(OrderTicket(), Slippage);
         }
      }
      return;
   }
   ORDER newOrders[];
   for (int i = 0; i < ArraySize(Orders); i++)
   {
      if (!FindOrder(Orders[i].order_ticket)) continue;
      int size = ArraySize(newOrders);
      ArrayResize(newOrders, size + 1);
      newOrders[size].symbol = Orders[i].symbol;
      newOrders[size].order_ticket = Orders[i].order_ticket;
      newOrders[size].order_type = Orders[i].order_type;
      newOrders[size].fast_hma_trend = Orders[i].fast_hma_trend;
   }
   
   ArrayFree(Orders);
   ArrayResize(Orders, ArraySize(newOrders));
   
   for (int i = 0; i < ArraySize(Orders); i++)
   {
      Orders[i].symbol = newOrders[i].symbol;
      Orders[i].order_ticket = newOrders[i].order_ticket;
      Orders[i].order_type = newOrders[i].order_type;
      Orders[i].fast_hma_trend = newOrders[i].fast_hma_trend;
   }
   ArrayFree(newOrders);
   int size = ArraySize(Orders);
   for (int i = 0; i < size; i++)
   {
      double fast_down = iCustom(Orders[i].symbol, Period(), "HMA_v2", 0, FastHMAPeriod, 0.0, 1, 0, 2, 1);
      double fast_up = iCustom(Orders[i].symbol, Period(), "HMA_v2", 0, FastHMAPeriod, 0.0, 1, 0, 1, 1);
      Orders[i].Reset(fast_up, fast_down);
      if (Orders[i].order_type == OP_BUY && Orders[i].fast_hma_trend != 1) continue;
      if (Orders[i].order_type == OP_SELL && Orders[i].fast_hma_trend != -1) continue;
      int OrderNum = -1;
      if (CloseByFastHMA == CHANGED)
      {
         if (Orders[i].order_type == OP_BUY && fast_down != EMPTY_VALUE) PositionClose(Orders[i].order_ticket, Slippage);
         else if (Orders[i].order_type == OP_SELL && fast_up != EMPTY_VALUE) PositionClose(Orders[i].order_ticket, Slippage);
      }
      else if (CloseByFastHMA == YELLOW)
      {
         if (Orders[i].order_type == OP_BUY && fast_up == EMPTY_VALUE) PositionClose(Orders[i].order_ticket, Slippage);
         else if (Orders[i].order_type == OP_SELL && fast_down == EMPTY_VALUE) PositionClose(Orders[i].order_ticket, Slippage);
      }
   }
   
}

bool FindOrder(int orderTicket)
{
   int size = OrdersTotal();
   for (int i = size - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (orderTicket != OrderTicket()) continue;
      return true;
   }
   return false;
}

void CloseByRSI()
{
   if (!ActiveRSIClose) return;
   //if (!ActiveRSIFilter) return;
   
   int size = OrdersTotal();
   for (int i = size - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (MagicNumber != OrderMagicNumber()) continue;
      double rsi = iRSI(OrderSymbol(), 0, RSIPeriod, RSIPrice, 1);
      if (rsi < RSILowLevel || rsi > RSIHighLevel) continue;
      PositionClose(OrderTicket(), Slippage);
   }
   
}