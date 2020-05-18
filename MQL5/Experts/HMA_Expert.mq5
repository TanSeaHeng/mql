//+------------------------------------------------------------------+
//|                                                   HMA_Expert.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#include <MT5Orders.mqh>
#include <Trade\PositionInfo.mqh>

input string P_Trading = "---------- General Trading Section ----------";
input double Lots = 1; //Quantity
input bool IsTarget = false; //Active Target Set
input double StopLoss = 500;
input double TakeProfit = 500;
input int MagicNumber = 2737923;
input string CommentOrder = "HMA EXPERT";

input string P_HMA = "---------- HMA Section ----------";
input ENUM_APPLIED_PRICE HMA_Price = PRICE_CLOSE; // HMA Price
input int HMA_Period = 100; // HMA Period

input string P_TrailStop      = "---------- Trailing Stop Parameters ----------";
input bool   UseTrailStop     = false;          // Activate Trail Stop
input double InpTrailingStart = 200;             // Trailing Start in Percents
input double InpTrailingStop  = 300;            // Trailing Distance in Percents
input double InpTrailingStep  = 50;             // Trailing Step in Percents

input string P_TimeFilter = "---------- Time Filter Section ----------";
input bool TimeFilter = false; // Activate Time Filter
input string TradeStartTime = "3:00"; // GMT TradingStartTime
input string TradeStopTime = "9:00"; // GMT TradingEndTime


int Slippage = 10;
CPositionInfo   m_position;     // trade position object

int m_HMA_Handle;
int OnInit()
  {
//---
   m_HMA_Handle = iCustom(Symbol(), Period(), "HMA_Trend", HMA_Price, HMA_Period);
   if(m_HMA_Handle==INVALID_HANDLE) 
   { 
      PrintFormat("Failed to create handle of the HMA indicator for the symbol %s/%s, error code %d", 
                  Symbol(), 
                  EnumToString(Period()), 
                  GetLastError()); 
      return(INIT_FAILED); 
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
   if(m_HMA_Handle!=INVALID_HANDLE) 
      IndicatorRelease(m_HMA_Handle); 
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
   if (!TimeFiltering()) return;
   TrailStop(InpTrailingStop, InpTrailingStep, InpTrailingStart);
   EntryOrder();
}
//+------------------------------------------------------------------+


void EntryOrder()
{
   double upTrend[2];
   CopyBuffer(m_HMA_Handle, 1, 0, 2, upTrend);
   double dnTrend[2];
   CopyBuffer(m_HMA_Handle, 2, 0, 2, dnTrend);
   
   if (upTrend[0] != 0 && dnTrend[0] == 0)
   {
      if (Positions(Symbol(), OP_BUY) > 0) return;
      ClosePositions(Symbol(), OP_SELL);
      PlaceMarketOrder(Symbol(), OP_BUY, Lots, StopLoss, TakeProfit, MagicNumber);
   }
   else if (dnTrend[0] != 0 && upTrend[0] == 0)
   {
      if (Positions(Symbol(), OP_SELL) > 0) return;
      ClosePositions(Symbol(), OP_BUY);
      PlaceMarketOrder(Symbol(), OP_SELL, Lots, StopLoss, TakeProfit, MagicNumber);
   }
}


int Positions(string sym="", int pt=-1) {

   int pos=0; //longs=0; shorts=0;
   string symbol;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i)) { // selects the position by index for further access to its properties
         if (sym == "") symbol = PositionGetSymbol(i);
         else symbol = sym;
         if (PositionGetSymbol(i)==symbol && PositionGetInteger(POSITION_MAGIC)==MagicNumber) {
            if (pt == PositionGetInteger(POSITION_TYPE) || pt == -1) {
               pos++;
            }
         }
      }
   }
   return(pos);
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Place Market Order function                                      |
//+------------------------------------------------------------------+
void PlaceMarketOrder(string sym, int oper, double lot, double sl=0, double tp=0, int mn=3232323, bool reverse=false) {   //  mn - Magic Number
   
   double d_sl=0, d_tp=0, oop=0;
   ulong ot=-1;
   string op="";

   MqlTick stTick;
   if (SymbolInfoTick(sym,stTick)==false) {
      Print("SymbolInfoTick function returned FALSE. Error=", GetLastError());
      return;
   }
   double _bid=CorrectPrice(sym,stTick.bid);
   double _ask=CorrectPrice(sym,stTick.ask);
   int dg=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   double po=SymbolInfoDouble(sym,SYMBOL_POINT);
   
   sl=(sl>1e-6 && sl<3.0)?3.0:sl;

     if (oper==ORDER_TYPE_BUY) {
        Print("   ***   Placing Market BUY. Ask="+DoubleToString(_ask,5)+", Bid="+DoubleToString(_bid,5)+", SL="+DoubleToString(sl,5)+", TP="+DoubleToString(tp,5)+
              " tick_size="+DoubleToString(SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE),5));
        //m_trade.Buy(lot,_Symbol,_ask,d_sl,d_tp,Comm);
        ot=OrderSend(sym,OP_BUY,lot,_ask,10,0,0,CommentOrder,mn,0,clrGreen);
        if (IsTarget)
        {
            if (ot>=0 && OrderSelect(ot,SELECT_BY_TICKET)) {
              oop=OrderOpenPrice();
              d_sl=(sl>1e-6)?CorrectPrice(sym,oop-sl*po):CorrectPrice(sym,0.0); d_sl=(d_sl>=_bid)?CorrectPrice(sym,_bid-3.0*po):d_sl; 
              //if (tp == 0) 
              d_tp = 0;
              //else d_tp=(tp>1e-6)?CorrectPrice(sym,oop+tp*po):CorrectPrice(sym,0.0); d_tp=(d_tp<=_ask)?CorrectPrice(sym,_ask+3.0*po):d_tp;
              Print("   ***   Modifying SL/TP. OrderOpenPrice="+DTS(oop, dg)+", Ask="+DTS(_ask, dg)+", Bid="+DTS(_bid, dg)+", SL="+DTS(d_sl, dg)+", TP="+DTS(d_tp, dg));
              OrderModify(ot,OrderOpenPrice(),d_sl,d_tp,0,clrGreen);
           }
        }
     }
     if (oper==ORDER_TYPE_SELL) {
        Print("   ***   Placing Market SELL. Bid="+DoubleToString(_bid,5)+", Ask="+DoubleToString(_ask,5)+", SL="+DoubleToString(sl,5)+", TP="+DoubleToString(tp,5)+
              " tick_size="+DoubleToString(SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE),5));
        //m_trade.Sell(lot,_Symbol,_bid,d_sl,d_tp,Comm);
        ot=OrderSend(sym,OP_SELL,lot,_bid,10,0,0,CommentOrder,mn,0,clrRed);
        if (IsTarget)
        {
           if (ot>=0 && OrderSelect(ot,SELECT_BY_TICKET)) {
              oop=OrderOpenPrice();
              d_sl=(sl>1e-6)?CorrectPrice(sym,oop+sl*po):CorrectPrice(sym,0.0); d_sl=(d_sl<=_ask)?CorrectPrice(sym,_ask+3.0*po):d_sl; 
              //if (tp == 0) 
              d_tp = 0;
              //else d_tp=(tp>1e-6)?CorrectPrice(sym,oop-tp*po):CorrectPrice(sym,0.0); d_tp=(d_tp>=_bid)?CorrectPrice(sym,_bid-3.0*po):d_tp;
              Print("   ***   Modifying SL/TP. OrderOpenPrice="+DTS(oop, dg)+", Ask="+DTS(_ask, dg)+", Bid="+DTS(_bid, dg)+", SL="+DTS(d_sl, dg)+", TP="+DTS(d_tp, dg));
              OrderModify(ot,OrderOpenPrice(),d_sl,d_tp,0,clrRed);
           }
        }        
     }
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
//| Close positions function                                         |
//+------------------------------------------------------------------+
void ClosePositions(string sym="", int oper=100) {

   string symbol;
   for(int j=0;j<4;j++) {
     for(int i=OrdersTotal()-1; i>=0; i--) {
       if (OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) {
         if (sym == "") symbol = OrderSymbol();
         else symbol = sym;
         if (OrderSymbol()==symbol) {
            if (OrderMagicNumber()==MagicNumber) {
               MqlTick stTick;
               if (SymbolInfoTick(symbol,stTick)==false) {
                  Print("SymbolInfoTick function returned FALSE. Error=", GetLastError());
                  return;
               }
               double _bid=stTick.bid;
               double _ask=stTick.ask;
               
               if (OrderType()==oper || oper==100) {
                  if (OrderType()==OP_BUY) { 
                     if (!OrderClose(OrderTicket(),OrderLots(),_bid,3,White))
                     Print("OrderClose error ",GetLastError());
                  }
                  if (OrderType()==OP_SELL) { 
                     if (!OrderClose(OrderTicket(),OrderLots(),_ask,3,White))
                     Print("OrderClose error ",GetLastError());
                  }
               }
            }
          }
       }
     }
  }
}
//+------------------------------------------------------------------+


bool IsNewBar(bool reinitialize=false) {
   
   static datetime SavedTime=0;
       datetime curTime=iTime(NULL,0,0);
   if (reinitialize) {SavedTime=0; return true;}
   
   if (curTime>SavedTime) {
         SavedTime=curTime;
         //Print("   ***   New Bar opened.");
         return(true);
   }
   else return(false);
}



//+------------------------------------------------------------------+
//| Normalize Double Custom function                                 |
//+------------------------------------------------------------------+
double ND_sl(double v, int digits)  {
   double ts=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE);
   v=NormalizeDouble(v/ts,0)*ts;
    return(NormalizeDouble(v,digits));
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Normalize Double Custom function                                 |
//+------------------------------------------------------------------+
double ND(double v, int digits)  {
    return(NormalizeDouble(v,digits));
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Double to String Custom function                                 |
//+------------------------------------------------------------------+
string DTS(double value, int digits) {
  return(DoubleToString(value,digits));
}
//+------------------------------------------------------------------+



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
      double pipSize = SymbolInfoDouble(OrderSymbol(), SYMBOL_POINT);
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


bool TimeFiltering()
{
   if (!TimeFilter) return true;
   datetime current = TimeGMT();
   string currstr = TimeToString(current, TIME_DATE);
   string startTime = currstr + " " + TradeStartTime;
   string stopTime = currstr + " " + TradeStopTime;
   datetime begin = StringToTime(startTime);
   datetime end = StringToTime(stopTime);
   if (begin >= end) begin = begin - 24 * 3600;
   bool EAActivated = (current>begin && current<end);  
   return EAActivated;
}
