
require 'paths'

local _gptable = {}
_gptable.current = nil
_gptable.term = nil

function lab.setgnuplotexe(exe)
   if paths.filep(exe) then
      _gptable.exe = exe
   else
      error(exe .. ' does not exist')
   end
end

function findgnuplot()
   if paths.dirp('C:\\') then
      _gptable.term = 'windows'
      return nil
   end
   _gptable.term = 'x11'
   return _gptable.term
end

local function getCurrentPlot()
   if _gptable.current == nil then
      lab.figure()
   end
   return _gptable[_gptable.current]
end

local function writeToCurrent(str)
   local _gp = getCurrentPlot()
   _gp:writeString(str .. '\n')
   _gp:synchronize()
end

-- t is the arguments for one plot at a time
local function getvars(t)
   local legend = nil
   local x = nil
   local y = nil
   local format = nil

   local function istensor(v)
      return type(v) == 'userdata' and torch.typename(v):sub(-6) == 'Tensor'
   end

   local function isstring(v)
      return type(v) == 'string'
   end

   if #t == 0 then
      error('empty argument list')
   end

   if #t >= 1 then
      if isstring(t[1]) then
	 legend = t[1]
      elseif istensor(t[1]) then
	 x = t[1]
      else
	 error('expecting [string,] tensor [,tensor] [,string]')
      end
   end
   if #t >= 2 then
      if x and isstring(t[2]) then
	 format = t[2]
      elseif x and istensor(t[2]) then
	 y = t[2]
      elseif legend and istensor(t[2]) then
	 x = t[2]
      else
	 error('expecting [string,] tensor [,tensor] [,string]')
      end
   end
   if #t >= 3 then
      if legend and x and istensor(t[3]) then
	 y = t[3]
      elseif legend and x and isstring(t[3]) then
	 format = t[3]
      elseif x and y and isstring(t[3]) then
	 format = t[3]
      else
	 error('expecting [string,] tensor [,tensor] [,string]')
      end
   end
   if #t == 4 then
      if legend and x and y and isstring(t[4]) then
	 format = t[4]
      else
	 error('expecting [string,] tensor [,tensor] [,string]')
      end
   end
   legend = legend or 'data'
   format = format or '.-'
   if not x then
      error('expecting [string,] tensor [,tensor] [,string]')
   end
   if not y then
      y = x
      x = lab.range(1,y:size(1))
   end
   if x:nDimension() ~= 1 or y:nDimension() ~= 1 then
      error('x and y are expected to be vectors x = ' .. x:nDimension() .. 'D y = ' .. y:nDimension() .. 'D')
   end
   return legend,x,y,format
end

function lab.gnuplot_string(legend,x,y,format)
   local hstr = 'plot '
   local dstr = ""
   local function gformat(f)
      if f == '.' then return 'points' end
      if f == '-' then return 'lines' end
      if f == '.-' then return 'linespoints' end
      error('format string expected to be . or - or .-')
   end
   for i=1,#legend do
      if i > 1 then hstr = hstr .. ' , ' end
      hstr = hstr .. " '-' title '" .. legend[i] .. "' with " .. gformat(format[i])
   end
   hstr = hstr .. '\n'
   for i=1,#legend do
      for j=1,x[i]:size(1) do
	 dstr = dstr .. string.format('%g %g\n',x[i][j],y[i][j])
      end
      dstr = string.format('%se\n',dstr)
   end
   return hstr,dstr
end

function lab.closeall()
   for i,v in pairs(_gptable) do
      if type(i) ==  number and torch.typename(v) == 'torch.PipeFile' then
	 v:close()
	 v=nil
      end
   end
   _gptable.current = nil
end

function lab.epsfigure(fname)
   local n = #_gptable+1
   _gptable[n] = torch.PipeFile('gnuplot -persist ','w')
   _gptable.current = n
   writeToCurrent('set term postscript eps enhanced color')
   writeToCurrent('set output \''.. fname .. '\'')
end

function lab.pngfigure(fname)
   local n = #_gptable+1
   _gptable[n] = torch.PipeFile('gnuplot -persist ','w')
   _gptable.current = n
   writeToCurrent('set term png')
   writeToCurrent('set output \''.. fname .. '\'')
end

function lab.print(fname)
   local suffix = fname:match('.+%.(.+)')
   local term = nil
   if suffix == 'eps' then term = 'postscript eps enhanced color'
   elseif suffix == 'png' then term = 'png'
   else error('only eps and png for print')
   end
   writeToCurrent('set term ' .. term)
   writeToCurrent('set output \''.. fname .. '\'')
   writeToCurrent('refresh')
   writeToCurrent('set term ' .. _gptable.term .. ' ' .. _gptable.current .. '\n')   
end

function lab.figure(n)
   local nfigures = #_gptable
   if not n or _gptable[n] == nil then -- we want new figure
      n = n or #_gptable+1
      _gptable[n] = torch.PipeFile('gnuplot -persist ','w')
   end
   _gptable.current = n
   writeToCurrent('set term ' .. _gptable.term .. ' ' .. n .. '\n')
end

function lab.gnuplot(legend,x,y,format)
   local hdr,data = lab.gnuplot_string(legend,x,y,format)
   writeToCurrent('set pointsize 2')
   writeToCurrent(hdr)
   writeToCurrent(data)
end

function lab.xlabel(label)
   local _gp = getCurrentPlot()
   writeToCurrent('set xlabel "' .. label .. '"')
   writeToCurrent('refresh')
end
function lab.ylabel(label)
   local _gp = getCurrentPlot()
   writeToCurrent('set ylabel "' .. label .. '"')
   writeToCurrent('refresh')
end
function lab.title(label)
   local _gp = getCurrentPlot()
   writeToCurrent('set title "' .. label .. '"')
   writeToCurrent('refresh')
end
function lab.grid(toggle)
   if not toggle then
      print('toggle expects 1 for grid on, 0 for grid off')
   end
   local _gp = getCurrentPlot()
   if toggle == 1 then
      writeToCurrent('set grid')
      writeToCurrent('refresh')
   elseif toggle == 0 then
      writeToCurrent('unset grid')
      writeToCurrent('refresh')
   else
      print('toggle expects 1 for grid on, 0 for grid off')
   end
end

function lab.gnuplotraw(str)
   writeToCurrent(str)
end

-- plot(x)
-- plot(x,'.'), plot(x,'.-')
-- plot(x,y,'.'), plot(x,y,'.-')
-- plot({x1,y1,'.'},{x2,y2,'.-'})
function lab.plot(...)
   if arg.n == 0 then
      error('no inputs, expecting at least a vector')
   end

   local formats = {}
   local xdata = {}
   local ydata = {}
   local legends = {}

   if type(arg[1]) == "table" then
      for i,v in ipairs(arg) do
	 local l,x,y,f = getvars(v)
	 legends[#legends+1] = l
	 formats[#formats+1] = f
	 xdata[#xdata+1] = x
	 ydata[#ydata+1] = y
      end
   else
      local l,x,y,f = getvars(arg)
      legends[#legends+1] = l
      formats[#formats+1] = f
      xdata[#xdata+1] = x
      ydata[#ydata+1] = y
   end
   lab.gnuplot(legends,xdata,ydata,formats)
end

findgnuplot()
