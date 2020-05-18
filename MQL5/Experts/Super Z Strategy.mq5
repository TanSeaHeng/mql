//+------------------------------------------------------------------+
//|                                             Super Z Strategy.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, crazyfxtrader Software Corp."
#property link      "http://crazyfxtrader.com/"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <MT5Orders.mqh>
#include <Trade\PositionInfo.mqh>

input string P_Trading = "---------- General Trading Section ----------";
input double Lots = 1; // Quantity
input int MagicNumber = 4524343;
input string CommentOrder = "Super Z Strategy";

input string P_Speical = "---------- Special Section ----------";
input ENUM_APPLIED_PRICE Price = PRICE_CLOSE; // src5
input int Length = 1440; // tf
input ENUM_TIMEFRAMES TimeFrame = PERIOD_D1; // res5
input int StMult = 1; // SuperTrend Multiplier
input int StPeriod = 50; // SuperTrend Period
//input bool Signal = false;

input string P_Renko = "---------- Renko Section ----------";
input ENUM_APPLIED_PRICE RenkoPrice = PRICE_CLOSE; // Renko Price
input double BoxSize = 0.03;

int Slippage = 10;
CPositionInfo   m_position;     // trade position object

double    ExtATRBuffer[];
double    ExtTRBuffer[];
int AtrPrev_calculated;
int RenkoIndex;

double         BoxOpenBuffer[];
double         BoxHighBuffer[];
double         BoxLowBuffer[];
double         BoxCloseBuffer[];
double         BoxColors[];
datetime       BoxStartTime[];

double         RenkoSrc[];
datetime       TimeSrc[];

//---
double         boxSize = 1;
int RatesTotal;
int RenkoPrev_calculatd;
int RenkoSrc_calculatd;

double         UpTrend[];
double         DownTrend[];
int            Trend[];
double         ReOpen[];
double         ReLow[];
double         ReClose[];
double         ReHigh[];

int CalcPrev_calculated;

double OpenBuffer[];
double HighBuffer[];
double LowBuffer[];
double CloseBuffer[];
datetime TimeBuffer[];


string BuyArrowName = "Buy Order ";
string SellArrowName = "Sell Order ";
int OrderSignal;

int OnInit()
  {
//---
   boxSize = BoxSize;
   RenkoPrev_calculatd = 0;
   AtrPrev_calculated = 0;
   CalcPrev_calculated = 0;
   OrderSignal = 0;
   RenkoSrc_calculatd = 0;
   RenkoIndex = 0;
   
   
   //RatesTotal = Bars(Symbol(), Period());
   //RenkoSrc_calculatd = GetRenkoSrc(RatesTotal, RenkoSrc_calculatd);
   //RenkoPrev_calculatd = RenkoArray(RatesTotal, RenkoPrev_calculatd, RenkoSrc, TimeSrc);
   ////GetOriginalArray(RatesTotal);
   //AtrPrev_calculated = ATRArray(RatesTotal, AtrPrev_calculated, 
   //   BoxOpenBuffer, BoxHighBuffer, BoxLowBuffer, BoxCloseBuffer, StPeriod);
   //CalcPrev_calculated = CalcStrategy(RatesTotal, CalcPrev_calculated);
      
//---
   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   FreeArray();
   ObjectsDeleteAll(0, -1, OBJ_ARROW_BUY);
   ObjectsDeleteAll(0, -1, OBJ_ARROW_SELL);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
      RatesTotal = Bars(Symbol(), Period());
      RenkoSrc_calculatd = GetRenkoSrc(RatesTotal, RenkoSrc_calculatd);
      RenkoPrev_calculatd = RenkoArray(RatesTotal, RenkoPrev_calculatd, RenkoSrc, TimeSrc);
      //GetOriginalArray(RatesTotal);
      AtrPrev_calculated = ATRArray(RatesTotal, AtrPrev_calculated, 
         BoxOpenBuffer, BoxHighBuffer, BoxLowBuffer, BoxCloseBuffer, StPeriod);
      CalcPrev_calculated = CalcStrategy(RatesTotal, CalcPrev_calculated);
  }
//+------------------------------------------------------------------+

double CalcALength()
{
   double result = 0;
   int multiplier = GetTimeFrameMultiplier();
   
   if (IsIntraday() && multiplier >= 1)
      result = Length / multiplier * 7;
   else if (!IsIntraday() && multiplier < 60)
      result = 60 / multiplier * 24 * 7;
   else result = 7;
   return result;
}


double CalcBLength()
{
   double result = 0;
   int multiplier = GetTimeFrameMultiplier();
   
   if (IsIntraday() && multiplier >= 1)
      result = 60 / multiplier * 7;
   else if (!IsIntraday() && multiplier < 60)
      result = 60 / multiplier * 24 * 7;
   else result = 7;
   return result;
}

double Func(const double& src[], int length)
{
   double n = 0.0;
   double s = 0.0;
   for (int i = 0; i < length - 1; i++)
   {
      double w = (length - i) * length;
      n += w;
      s += src[i] * w;
   }
   if (n == 0) return 0;
   return s / n;
}


bool IsIntraday()
{
   if (Period() < PERIOD_H1) return true;
   else return false;
   return false;
}

int GetTimeFrameMultiplier()
{
   switch (Period())
   {
      case PERIOD_M1:
         return 1;
      case PERIOD_M2:
         return 2;
      case PERIOD_M3:
         return 3;
      case PERIOD_M4:
         return 5;
      case PERIOD_M5:
         return 5;
      case PERIOD_M6:
         return 6;
      case PERIOD_M10:
         return 10;
      case PERIOD_M12:
         return 12;
      case PERIOD_M15:
         return 15;
      case PERIOD_M20:
         return 20;
      case PERIOD_M30:
         return 30;
      case PERIOD_H1:
         return 1;
      case PERIOD_H2:
         return 2;
      case PERIOD_H3:
         return 3;
      case PERIOD_H4:
         return 4;
      case PERIOD_H6:
         return 6;
      case PERIOD_H8:
         return 8;
      case PERIOD_H12:
         return 12;
      case PERIOD_D1:
         return 1;
      case PERIOD_W1:
         return 1;
      case PERIOD_MN1:
         return 1;
   }
   return 1;
}


int ATRArray(int rates_total,
                const int prev_calculated,
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                int ExtPeriodATR)
  {
   int i,limit;
//--- check for bars count
   if(rates_total<=ExtPeriodATR)
      return(0); // not enough bars for calculation
//--- preliminary calculations

   ArrayResize(ExtATRBuffer, rates_total);
   ArrayResize(ExtTRBuffer, rates_total);
   if(prev_calculated==0)
     {
      ExtTRBuffer[0]=0.0;
      ExtATRBuffer[0]=0.0;
      //--- filling out the array of True Range values for each period
      for(i=1;i<rates_total && !IsStopped();i++)
         ExtTRBuffer[i]=MathMax(high[i],close[i-1])-MathMin(low[i],close[i-1]);
      //--- first AtrPeriod values of the indicator are not calculated
      double firstValue=0.0;
      for(i=1;i<=ExtPeriodATR;i++)
        {
         ExtATRBuffer[i]=0.0;
         firstValue+=ExtTRBuffer[i];
        }
      //--- calculating the first value of the indicator
      firstValue/=ExtPeriodATR;
      ExtATRBuffer[ExtPeriodATR]=firstValue;
      limit=ExtPeriodATR+1;
     }
   else limit=prev_calculated-1;
//--- the main loop of calculations
   for(i=limit;i<rates_total && !IsStopped();i++)
     {
      ExtTRBuffer[i]=MathMax(high[i],close[i-1])-MathMin(low[i],close[i-1]);
      ExtATRBuffer[i]=ExtATRBuffer[i-1]+(ExtTRBuffer[i]-ExtTRBuffer[i-ExtPeriodATR])/ExtPeriodATR;
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }


//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int RenkoArray(const int rates_total,
                const int prev_calculated,
                const double &close[], const datetime & time[])
{
//---
   int limit = 0;
   if (prev_calculated != 0) limit = prev_calculated - 1;
   int i = limit;
   for (; i < rates_total;i++)
   {
      BufferResize(RenkoIndex);
      if (OpenBuffer[RenkoIndex] == 0)
      {
         if (RenkoIndex == 0)
         {
            OpenBuffer[RenkoIndex] = close[i];
            TimeBuffer[RenkoIndex] = time[i];
            HighBuffer[RenkoIndex] = close[i];
            LowBuffer[RenkoIndex] = close[i];
            CloseBuffer[RenkoIndex] = close[i];
         }
      }
      else
      {
         if (MathAbs(OpenBuffer[RenkoIndex] - CloseBuffer[RenkoIndex]) != boxSize)
         {
            if (OpenBuffer[RenkoIndex] - boxSize > close[i]) 
            {
               CloseBuffer[RenkoIndex] = OpenBuffer[RenkoIndex] - boxSize;
               if (LowBuffer[RenkoIndex] > CloseBuffer[RenkoIndex]) LowBuffer[RenkoIndex] = CloseBuffer[RenkoIndex];
            }
            else if (OpenBuffer[RenkoIndex] + boxSize < close[i]) 
            {
               CloseBuffer[RenkoIndex] = OpenBuffer[RenkoIndex] + boxSize;
               if (HighBuffer[RenkoIndex] < CloseBuffer[RenkoIndex]) HighBuffer[RenkoIndex] = CloseBuffer[RenkoIndex];
            }
            else
            {
               if (LowBuffer[RenkoIndex] > close[i]) LowBuffer[RenkoIndex] = close[i];
               if (HighBuffer[RenkoIndex] < close[i]) HighBuffer[RenkoIndex] = close[i];
               continue;
            }
         }
         if (OpenBuffer[RenkoIndex] < CloseBuffer[RenkoIndex])
         {
            while (OpenBuffer[RenkoIndex] - boxSize > close[i] || CloseBuffer[RenkoIndex] + boxSize < close[i])
            {
               if (OpenBuffer[RenkoIndex] - boxSize > close[i])
               {
                  RenkoIndex++;
                  BufferResize(RenkoIndex);
                  OpenBuffer[RenkoIndex] = OpenBuffer[RenkoIndex - 1];
                  CloseBuffer[RenkoIndex] = OpenBuffer[RenkoIndex] - boxSize;
                  HighBuffer[RenkoIndex] = OpenBuffer[RenkoIndex];
                  LowBuffer[RenkoIndex] = CloseBuffer[RenkoIndex];
                  TimeBuffer[RenkoIndex] = time[i];
               }
               else
               {
                  RenkoIndex++;
                  BufferResize(RenkoIndex);
                  OpenBuffer[RenkoIndex] = CloseBuffer[RenkoIndex - 1];
                  CloseBuffer[RenkoIndex] = OpenBuffer[RenkoIndex] + boxSize;
                  HighBuffer[RenkoIndex] = CloseBuffer[RenkoIndex];
                  LowBuffer[RenkoIndex] = OpenBuffer[RenkoIndex];
                  TimeBuffer[RenkoIndex] = time[i];
               }
            }            
         }
         else if (OpenBuffer[RenkoIndex] > CloseBuffer[RenkoIndex])
         {
            while (OpenBuffer[RenkoIndex] + boxSize < close[i] || CloseBuffer[RenkoIndex] - boxSize > close[i])
            {
               if (OpenBuffer[RenkoIndex] + boxSize < close[i])
               {
                  RenkoIndex++;
                  BufferResize(RenkoIndex);
                  OpenBuffer[RenkoIndex] = OpenBuffer[RenkoIndex - 1];
                  CloseBuffer[RenkoIndex] = OpenBuffer[RenkoIndex] + boxSize;
                  HighBuffer[RenkoIndex] = CloseBuffer[RenkoIndex];
                  LowBuffer[RenkoIndex] = OpenBuffer[RenkoIndex];
                  TimeBuffer[RenkoIndex] = time[i];
               }
               else
               {
                  RenkoIndex++;
                  BufferResize(RenkoIndex);
                  OpenBuffer[RenkoIndex] = CloseBuffer[RenkoIndex - 1];
                  CloseBuffer[RenkoIndex] = OpenBuffer[RenkoIndex] - boxSize;
                  HighBuffer[RenkoIndex] = OpenBuffer[RenkoIndex];
                  LowBuffer[RenkoIndex] = CloseBuffer[RenkoIndex];
                  TimeBuffer[RenkoIndex] = time[i];
               }
            }
         }
      }
   }
//---
   
//---
   ArrayResize(BoxStartTime, rates_total);
   ArrayResize(BoxOpenBuffer, rates_total);
   ArrayResize(BoxHighBuffer, rates_total);
   ArrayResize(BoxLowBuffer, rates_total);
   ArrayResize(BoxCloseBuffer, rates_total);
   ArrayResize(BoxColors, rates_total);
   
   ArrayInitialize(BoxOpenBuffer, 0.0);
   ArrayInitialize(BoxHighBuffer, 0.0);
   ArrayInitialize(BoxLowBuffer, 0.0);
   ArrayInitialize(BoxCloseBuffer, 0.0);
   ArrayInitialize(BoxStartTime, 0);
   ArrayInitialize(BoxColors, 0);
   
//---
   if (rates_total - 1 - RenkoIndex < 0) i = RenkoIndex - rates_total + 1;
   else i = 0;
   for (; i <= RenkoIndex; i++)
   {
      BoxOpenBuffer[rates_total - 1 - RenkoIndex + i] = OpenBuffer[i];
      BoxHighBuffer[rates_total - 1 - RenkoIndex + i] = HighBuffer[i];
      BoxCloseBuffer[rates_total - 1 - RenkoIndex + i] = CloseBuffer[i];
      BoxLowBuffer[rates_total - 1 - RenkoIndex + i] = LowBuffer[i];
      BoxStartTime[rates_total - 1 - RenkoIndex + i] = TimeBuffer[i];
      if (OpenBuffer[i] < CloseBuffer[i])
      {
         BoxColors[rates_total - 1 - RenkoIndex + i] = 0;
      }
      else if (OpenBuffer[i] > CloseBuffer[i])
      {
         BoxColors[rates_total - 1 - RenkoIndex + i] = 1;
      }
      else if (i != 0)
      {
         if (OpenBuffer[i - 1] < CloseBuffer[i - 1])
            BoxColors[rates_total - 1 - RenkoIndex + i] = 0;
         else if (OpenBuffer[i - 1] > CloseBuffer[i - 1])
            BoxColors[rates_total - 1 - RenkoIndex + i] = 1;
         else BoxColors[rates_total - 1 - RenkoIndex + i] = 0;
      }
      else BoxColors[rates_total - 1 - RenkoIndex + i] = 0;
   }
   
//---
//--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+

int GetRenkoSrc(const int ratesTotal, const int preCalculated)
{
   int limit = 0;
   if (preCalculated != 0) limit = preCalculated - 1;
   
   ArrayResize(RenkoSrc, ratesTotal);
   ArrayResize(TimeSrc, ratesTotal);
   switch (RenkoPrice)
   {
      case PRICE_CLOSE:
         for (int i = limit; i < ratesTotal; i++)
         {
            RenkoSrc[i] = iClose(Symbol(), 0, ratesTotal - 1 - i);
            TimeSrc[i] = iTime(Symbol(), 0, ratesTotal - 1 - i);
         }
         break;
      case PRICE_OPEN:
         for (int i = limit; i < ratesTotal; i++)
            RenkoSrc[i] = iOpen(Symbol(), 0, ratesTotal - 1 - i);
         break;
      case PRICE_HIGH:
         for (int i = limit; i < ratesTotal; i++)
            RenkoSrc[i] = iHigh(Symbol(), 0, ratesTotal - 1 - i);
         break;
      case PRICE_LOW:
         for (int i = limit; i < ratesTotal; i++)
            RenkoSrc[i] = iLow(Symbol(), 0, ratesTotal - 1 - i);
         break;
      default:
         for (int i = limit; i < ratesTotal; i++)
            RenkoSrc[i] = iClose(Symbol(), 0, ratesTotal - 1 - i);
         break;
   }
   return ratesTotal;
}


int CalcStrategy(const int ratesTotal, const int preCalculated)
{
   ArrayResize(UpTrend, ratesTotal);
   ArrayResize(DownTrend, ratesTotal);
   ArrayResize(Trend, ratesTotal);
   ArrayResize(ReOpen, ratesTotal);
   ArrayResize(ReClose, ratesTotal);
   ArrayResize(ReHigh, ratesTotal);
   ArrayResize(ReLow, ratesTotal);
   int limit = 0;
   if (preCalculated != 0) limit = preCalculated - 1;
   
   for (int i = limit; i < ratesTotal; i++)
   {
      UpTrend[i] = 0;
      DownTrend[i] = 0;
      Trend[i] = 0;
      if (i - 1 < 0) 
      {
         continue;
      }
      ENUM_TIMEFRAMES timeframe = Period();
      datetime curTime = BoxStartTime[i];//iTime(Symbol(), timeframe, ratesTotal - 1 - i);
      datetime starttime = D'2020.05.05 20:10:00'; // Expired Date
      datetime endtime = D'2020.05.05 20:20:00'; // Expired Date
      double high = BoxHighBuffer[i];//iHigh(Symbol(), 0, curBar);//
      double low = BoxLowBuffer[i];//iLow(Symbol(), 0, curBar);//
      
      datetime displayTime = iTime(Symbol(), _Period, ratesTotal - 1 - i);
      
      
      //if (ratesTotal - 800 == i)
      //{
      //   DrawSell(SellArrowName + IntegerToString(i), displayTime, high, clrWhite);
      //}
      //datetime preTime = iTime(Symbol(), timeframe, ratesTotal - 1 - i + 1);
      
      int barShift = iBarShift(Symbol(), TimeFrame, curTime);
      //int preShift = iBarShift(Symbol(), TimeFrame, preTime);
      
      ReLow[i] = iLow(Symbol(), TimeFrame, barShift);
      ReHigh[i] = iHigh(Symbol(), TimeFrame, barShift);
      ReClose[i] = iClose(Symbol(), TimeFrame, barShift);
      ReOpen[i] = iOpen(Symbol(), TimeFrame, barShift);
      double up_lev = ReLow[i] - 1;//(StMult * ExtATRBuffer[i]);
      double dn_lev = ReHigh[i] + 1;//(StMult * ExtATRBuffer[i]);
      double preClose = ReClose[i - 1];
      double close = ReClose[i];
      
      //if (iTime(Symbol(), TimeFrame, barShift) != iTime(Symbol(), TimeFrame, preShift))
      //   close = ReClose[i - 1];
      
      //if (barShift != preShift) 
      if (preClose > UpTrend[i - 1]) UpTrend[i] = MathMax(up_lev, UpTrend[i - 1]);
      else UpTrend[i] = up_lev;
      
      if (preClose < DownTrend[i - 1]) DownTrend[i] = MathMin(dn_lev, DownTrend[i - 1]);
      else DownTrend[i] = dn_lev;
      
      if (close > DownTrend[i - 1]) Trend[i] = 1;
      else if (close < UpTrend[i - 1]) Trend[i] = -1;
      else Trend[i] = Trend[i - 1];
      
      if (i - 2 < 0) continue;
      double st_line = Trend[i - 1] == 1? UpTrend[i - 1]: DownTrend[i - 1];
      double pre_st_line = Trend[i - 2] == 1? UpTrend[i - 2]: DownTrend[i - 2];
      bool buy = false, sell = false;
      
      if (ReClose[i - 2] < pre_st_line && ReClose[i - 1] > st_line) buy = true;
      if (ReClose[i - 2] > pre_st_line && ReClose[i - 1] < st_line) sell = true;
      
      int curBar = iBarShift(Symbol(), 0, curTime);
      
      
      if (buy)
      {
         if (i == ratesTotal - 1)
         {
            if (Positions(Symbol(), POSITION_TYPE_BUY) == 0)
            {
               ClosePositions(Symbol(), OP_SELL);
               PlaceMarketOrder(Symbol(), ORDER_TYPE_BUY, NormalizeLot(Lots), 0, 0, MagicNumber);  
            }
         }
         //else
         //{
         //   if (OrderSignal != 1)
         //   {
         //      DrawBuy(BuyArrowName + TimeToString(curTime), displayTime, low);
         //      OrderSignal = 1;
         //   }
         //}
      }
      if (sell)
      {
         if (i == ratesTotal - 1)
         {
            if (Positions(Symbol(), POSITION_TYPE_SELL) == 0)
            {
               ClosePositions(Symbol(), OP_BUY);
               PlaceMarketOrder(Symbol(), ORDER_TYPE_SELL, NormalizeLot(Lots), 0, 0, MagicNumber);
            }
         }
         //else
         //{
         //   if (OrderSignal != -1)
         //   {
         //      DrawSell(SellArrowName + TimeToString(curTime), displayTime, high);
         //      OrderSignal = -1;
         //   }            
         //}
      }
   }
   return ratesTotal;
}



void DrawBuy(string name, datetime time, double price, color clr = clrGreen)
{
   ObjectCreate(0, name, OBJ_ARROW_BUY, 0, time, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ChartRedraw();
}

void DrawSell(string name, datetime time, double price, color clr = clrRed)
{
   ObjectCreate(0, name, OBJ_ARROW_SELL, 0, time, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ChartRedraw();
}

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
        //if (ot>=0 && OrderSelect(ot,SELECT_BY_TICKET)) {
        //   oop=OrderOpenPrice();
        //   d_sl=(sl>1e-6)?CorrectPrice(sym,oop-sl*po):CorrectPrice(sym,0.0); d_sl=(d_sl>=_bid)?CorrectPrice(sym,_bid-3.0*po):d_sl; 
        //   //if (tp == 0) 
        //   d_tp = 0;
        //   //else d_tp=(tp>1e-6)?CorrectPrice(sym,oop+tp*po):CorrectPrice(sym,0.0); d_tp=(d_tp<=_ask)?CorrectPrice(sym,_ask+3.0*po):d_tp;
        //   Print("   ***   Modifying SL/TP. OrderOpenPrice="+DTS(oop, dg)+", Ask="+DTS(_ask, dg)+", Bid="+DTS(_bid, dg)+", SL="+DTS(d_sl, dg)+", TP="+DTS(d_tp, dg));
        //   OrderModify(ot,OrderOpenPrice(),d_sl,d_tp,0,clrGreen);
        //}
     }
     if (oper==ORDER_TYPE_SELL) {
        Print("   ***   Placing Market SELL. Bid="+DoubleToString(_bid,5)+", Ask="+DoubleToString(_ask,5)+", SL="+DoubleToString(sl,5)+", TP="+DoubleToString(tp,5)+
              " tick_size="+DoubleToString(SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE),5));
        //m_trade.Sell(lot,_Symbol,_bid,d_sl,d_tp,Comm);
        ot=OrderSend(sym,OP_SELL,lot,_bid,10,0,0,CommentOrder,mn,0,clrRed);
        //if (ot>=0 && OrderSelect(ot,SELECT_BY_TICKET)) {
        //   oop=OrderOpenPrice();
        //   d_sl=(sl>1e-6)?CorrectPrice(sym,oop+sl*po):CorrectPrice(sym,0.0); d_sl=(d_sl<=_ask)?CorrectPrice(sym,_ask+3.0*po):d_sl; 
        //   //if (tp == 0) 
        //   d_tp = 0;
        //   //else d_tp=(tp>1e-6)?CorrectPrice(sym,oop-tp*po):CorrectPrice(sym,0.0); d_tp=(d_tp>=_bid)?CorrectPrice(sym,_bid-3.0*po):d_tp;
        //   Print("   ***   Modifying SL/TP. OrderOpenPrice="+DTS(oop, dg)+", Ask="+DTS(_ask, dg)+", Bid="+DTS(_bid, dg)+", SL="+DTS(d_sl, dg)+", TP="+DTS(d_tp, dg));
        //   OrderModify(ot,OrderOpenPrice(),d_sl,d_tp,0,clrRed);
        //}
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

void FreeArray()
{
    
   ArrayFree(ExtATRBuffer);
   ArrayFree(ExtTRBuffer);
   
   
   
   ArrayFree(BoxOpenBuffer);
   ArrayFree(BoxHighBuffer);
   ArrayFree(BoxLowBuffer);
   ArrayFree(BoxCloseBuffer);
   ArrayFree(BoxColors);
   ArrayFree(RenkoSrc);
   ArrayFree(TimeSrc);
   //---
   
   ArrayFree(UpTrend);
   ArrayFree(DownTrend);
   ArrayFree(Trend);
   ArrayFree(ReOpen);
   ArrayFree(ReClose);
   ArrayFree(ReHigh);
   ArrayFree(ReHigh);
}

void GetOriginalArray(int ratesTotal)
{
   ArrayResize(BoxCloseBuffer, ratesTotal);
   ArrayInitialize(BoxCloseBuffer, 0);
   ArrayResize(BoxOpenBuffer, ratesTotal);
   ArrayInitialize(BoxOpenBuffer, 0);
   ArrayResize(BoxHighBuffer, ratesTotal);
   ArrayInitialize(BoxHighBuffer, 0);
   ArrayResize(BoxLowBuffer, ratesTotal);
   ArrayInitialize(BoxLowBuffer, 0);
   CopyClose(_Symbol, Period(), 0, ratesTotal, BoxCloseBuffer);
   CopyOpen(_Symbol, Period(), 0, ratesTotal, BoxOpenBuffer);
   CopyHigh(_Symbol, Period(), 0, ratesTotal, BoxHighBuffer);
   CopyLow(_Symbol, Period(), 0, ratesTotal, BoxLowBuffer);
}


void BufferResize(int index)
{
   if (ArraySize(OpenBuffer) <= index)
   {
      int preSize = ArraySize(OpenBuffer);
      ArrayResize(OpenBuffer, preSize + 100);
      ArrayResize(CloseBuffer, preSize + 100);
      ArrayResize(HighBuffer, preSize + 100);
      ArrayResize(LowBuffer, preSize + 100);
      ArrayResize(TimeBuffer, preSize + 100);
      for (int i = preSize; i < preSize + 100; i++)
      {
         OpenBuffer[i] = 0;
         CloseBuffer[i] = 0;
         HighBuffer[i] = 0;
         LowBuffer[i] = 0;
         TimeBuffer[i] = 0;
      }
   }
}