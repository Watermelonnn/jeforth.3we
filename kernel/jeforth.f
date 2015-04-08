code init		( -- ) \ Initialize g.members that are moved out from jeforth.js which is thus kept pure.
				// An array's length is array.length but there's no such thing of hash.length for hash{}.
				// memberCount(object) gets the given object's member count which is also a hash table's length.
				g.memberCount = function (obj) {
					var i=0;
					for(var members in obj) i++;
					return i;
				}
				// This is a useful common tool. Compare two arrays.
				g.isSameArray = function (a,b) {
					if (a.length != b.length) {
						return false;
					} else {
						for (var i=0; i < a.length; i++){
							var ta = typeof(a[i]);
							var tb = typeof(b[i]);
							if (ta == tb) {
								if (ta == "number"){
									if (isNaN(a[i]) && isNaN(b[i])) continue; // because (NaN == NaN) 的結果是 false 所以要特別處理。
								}
								if (ta == "object") {  // 怎麼比較 obj? v2.05 之後用 memberCount()
									if (g.memberCount(a[i]) != g.memberCount(b[i])) return false;
								} else if (a[i] != b[i]) return false;
							} else if (a[i] != b[i]) return false;
						}
						return true;
					}
				}
				// Tool, check if the item exists in the array or is it a member in the hash.
				// return {flag, key}
				g.isMember = function (item, thing){
					var result = {flag:false, key:0};
					if (mytypeof(thing) == "array") {
						for (var i in thing) {
							if (item == thing[i]) {
								result.flag = true;
								result.key = parseInt(i); // array 被 JavaScript 當作 object 而 i 是個 string, 所以要轉換!
								break;
							}
						}
					} else { // if obj is not an array then assume it's an object
						for (var i in thing) {
							if (item == i) {
								result.flag = true;
								result.key = thing[i];
								break;
							}
						}
					}
					return result; // {flag:boolean, value:(index of the array or value of the obj member)}
				}
				// How to clear all setInterval() and setTimeOut() without knowing their ID?
				// http://stackoverflow.com/questions/8769598/how-to-clear-all-setinterval-and-settimeout-without-knowing-their-id
				// 缺點是 g.setTimeout.registered() 會大量堆積，需 delete(g.setTimeout.registered()[id.toString()]) 既然還得記住
				// timeoutId 使得 g.setTimeout() 的好處大打折扣。 查看： js> g.setTimeout.registered() (see)
				// setInterval 比較不會大量堆積，最好還是要適時 delete。查看：js> g.setInterval.registered() (see)
				g.setInterval = (function(){
					var registered={};
					f = function(a,b){
						var id = setInterval(a,b);
						registered[id.toString()] = id;
						return id;
					};
					f.clearAll = function(){
						for(var r in registered){clearInterval( registered[r] )}
						registered={};
					};
					f.registered = function(){return(registered)};
					return f;    
				})();
				g.setTimeout = (function(){
					var registered={};
					f = function(a,b){
						var id = setTimeout(a,b);
						registered[id.toString()] = id;
						return id;
					};
					f.clearAll = function(){
						for(var r in registered){clearTimeout( registered[r] )}
						registered={};
					};
					f.registered = function(){return(registered)};
					return f;    
				})();
				// This is a useful common tool. Help to recursively see an object or forth Word.
				// For forth Words, view the briefing. For other objects, try to see into it.
				g.see = function (obj,tab){
					if (tab==undefined) tab = "  "; else tab += "  ";
					switch(mytypeof(obj)){
						case "object" :
						case "array" :
							if (obj.constructor != Word) {
								if (obj&&obj.toString) 
									print(obj.toString() + '\n');
								else 
									print(Object.prototype.toString.apply(obj) + '\n');
								for(var i in obj) {
									print(tab + i + " : ");  // Entire array already printed here.
									if (obj[i] && obj[i].toString || obj[i]===0) 
										print(tab + obj[i].toString() + '\n');
									else
										print(tab + Object.prototype.toString.apply(obj[i]) + '\n');
								}
								break;  // if is Word then do default
							}
						default : // Word(), Constant(), number, string, null, undefined
							var ss = obj + ''; // Print-able test
							print(ss + " (" + mytypeof(obj) + ")\n");
					}
				}
				g.debugInner = function (entry, resuming) {
					var w = phaseA(entry); // 翻譯成恰當的 w.
					do{
						while(w) { // 這裡是 forth inner loop 決戰速度之所在，奮力衝鋒！
							if(bp<0||bp==ip){vm.jsc.prompt='ip='+ip+" jsc>";eval(vm.jsc.xt)}; // 可用 bp=ip 設斷點, debug colon words.
							ip++; // Forth 的通例，inner loop 準備 execute 這個 word 之前，IP 先指到下一個 word.
							phaseB(w); // 針對不同種類的 w 採取正確方式執行它。
							w = dictionary[ip];
						}
						if(w===0) break; else ip = rstack.pop(); // w==0 is suspend, abort inner but reserve rstack
						if(resuming) w = dictionary[ip];
					} while(ip && resuming); // ip==0 means resuming has done
				}
				end-code init

code version    ( -- revision ) \ print the greeting message and return the revision code
				push(kvm.greeting()) end-code

code <selftest>	( <statements> -- ) \ Collect self-test statements. interpret-only
				push(nexttoken("</selftest>"));
				end-code

code </selftest> ( "selftest" -- ) \ Save the self-test statements to <selftest>.buffer. interpret-only
				var my = tick("<selftest>");
				my.buffer = my.buffer || ""; // initialize my.buffer
                my.buffer += pop();
                end-code

				<selftest>
					<comment>
					程式只要稍微大一點點，就得附上一些 self-test 讓它伺機檢查自身。隨便有做，穩定性
					就會提升一大步。 Forth 的結構全部都是 global words， 改動的時候自由無限， 又難
					以一一去檢討影響到了哪些 words, 不讓它全面自動測試， 十分令人擔憂。  我當初寫
					jeforth.WSH  從開始就盡量做了些 self-test, 此舉甚佳， 後來不斷改版的過程中， 被
					self-test 逮到的問題不計其數。 如果沒有事先埋下 test 機制，這些問題就必定藏在裡
					面了。 隨便做，跳著做，有做就有效。與其努力抓 bug 不如早點把 self-test 做進去。

					Self-test 的執行時機是程式開始時，或開機時。沒有特定任務就做 self-test.

					include 各個 modules 時，循序就做 self-test。藉由 forth 的 marker , (forget) 等
					self-test 用過即丟， 只花時間，不佔空間。花平時的開發時間不要緊，有特定任務時就
					跳過 self-test，是則完全不佔執行系統任何時間空間，只佔 source code 的篇幅。

					我嘗試了種種的 self-test 寫法。有的很醜，混在正常程式裡面相當有礙視線；不醜的很
					累，佔很大 source code 篇幅。總算因著 self-test 的投資報酬很高,都值得。一直希望
					能找出某種天生的 self-test 機制來簡化工作。對 jeforth.3nw 而言，這很有希望。因為
					每個 word 都是 object 都有 constructor , prototype 等，答案似乎呼之欲出。

					燕南曰: Forth 特色 只有想不到 沒有做不到.... 該做的就做...

					以下是發展到目前最好的方法，jeforth.js kernel  裡只有 code end-code 兩個基本 
					words, 剛進到 jeforth.f  只憑這兩個基本 words 就馬上要為每個 word 都做 self-test 
					原本是很困難的。 然而，jeforth.f 是整個檔案一次讀進來成為大大的一個 TIB 的， 所
					以其中已經含有 jeforth.f 的全部功能。如果 self-test 安排在所有的 words 都 load 
					好以後做，資源充分就不覺有困難。好玩的是，進一步，利用〈selftest〉〈/selftest〉這
					對「文字蒐集器」在任意處所蒐集「測試程式的本文」，最後再一次把它當成 TIB 執行。實
					用上〈selftest〉〈/selftest〉出現在每個 word 定義處，裡頭可以放心自由地使用尚未出
					生的「未來 words」, 感覺很奇異，但對寫程式時的頭腦有很大的幫助。 </comment>
					marker ~~selftest~~
					include kernel/selftest.f
					.( *** Start self-test ) cr
					s" *** Data stack should be empty ... " .
						depth not [if] .( pass) cr [else] .( failed!) cr \s [then]
					.( *** Rreturn stack should have less than 2 cells ... )
						js> rstack.length dup . space 2 <= [if] .( pass) cr [else] .( failed!) cr \s [then]
					*** version should return a number . . .
						selftest-invisible
						version
						selftest-visible
						js> typeof(pop())=="number" ==>judge
					[if] <js> [
					',', '.', '."', '.(', '//', ':', ';', '</'+'text>', '<=', '<text>', '@',
					'[else]', '[if]', '[then]', '\\', '\\s', 'code', 'cr', 'depth', 'drop',
					'dup', 'else', 'end-code', 'if', 'js:', 'js>', 'marker', 'not', 'space',
					'then', 'variable', '<selftest>', '</self'+'test>', '(marker)', 'variable',
					'word', '<js>', '</'+'jsV>'
					] </jsV> all-pass [then]
				</selftest>

code execute    ( Word|"name"|address|empty -- ... ) \ Execute the given word or the last() if stack is empty.
				execute(pop()); end-code

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** execute "drop" should drop the TOS ...
						123 s" drop" execute
						456 ' drop execute
						depth 0= ==>judge drop
				</selftest>

code interpret-only  ( -- ) \ Make the last new word an interpret-only.
                last().interpretonly=true;
                end-code interpret-only

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** interpret-only makes dummy interpret-only ...
						: dummy ; interpret-only
						' dummy js> pop().interpretonly ==>judge drop
						(forget)
				</selftest>


code immediate  ( -- ) \ Make the last new word an immediate.
                last().immediate=true
                end-code

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** immediate makes dummy immediate ...
						: dummy ; immediate
						' dummy js> pop().immediate ==>judge drop
						(forget)
				</selftest>

code .((		( <str> -- ) \ Print following string down to '))' immediately.
				print(nexttoken('\\)\\)'));ntib+=2; end-code immediate

code \          ( <comment> -- ) \ Comment down to the next '\n'.
                nexttoken('\n') end-code immediate

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** \ tib line after \ should be ignored ...
						111 \ 222
						: dummy
							222
							\ 333 444 555
						;
						last execute + depth + 334 = ==>judge drop
						(forget)
				</selftest>

code \s         ( -- ) \ Stop outer loop which may be loading forth source files.
				stop=true; 
                ntib=tib.length; // 可能沒用，雙重保險。
                end-code
				
				<selftest>
					\ depth [if] .( Data stack should be empty! ) cr \s [then]
					\ *** \s should ignore the remaining TIB ...
					\ 	<js> fortheval("123 \\s 324 32  ... ignore every thing !!!!"); </jsN>
					\ 	depth + 124 = ==>judge drop
				</selftest>

code compile-only  ( -- ) \ Make the last new word a compile-only.
                last().compileonly=true
                end-code interpret-only

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** compile-only makes dummy compile-only ...
						: dummy ; compile-only
						' dummy js> pop().compileonly ==>judge drop
						(forget)
				</selftest>

\ ------------------ Fundamental words ------------------------------------------------------

code (create)	( "name" -- ) \ Create a code word that has a dummy xt, not added into wordhash{} yet
                if(!(newname=pop())) panic("Create what?\n", tib.length-ntib>100);
                if(isReDef(newname)) print("reDef "+newname+"\n"); // 若用 tick(newname) 就錯了
                current_word_list().push(new Word([newname,function(){}]));
				last().vid = current; // vocabulary ID
				last().wid = current_word_list().length-1; // word ID
				last().type = "colon-create";
				last().help = newname + " " + packhelp(); // help messages packed
                end-code

code reveal		( -- ) \ Add the last word into wordhash
				wordhash[last().name]=last() end-code
				\ We don't want the last word to be seen during its colon definition.
				\ So reveal is done in ';' command.

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** (create) should create a new word ...
						char ~(create)~ (create)
						js> last().name char ~(create)~ = ==>judge [if]
						<js> ['char', '</j'+'sV>', '(create)'] </jsV> all-pass
						[then]
						(forget)
				</selftest>

code //         ( <comment> -- ) \ Give help message to the new word.
                var s = nexttoken('\n|\r');
                last().help = newname + " " + s;
                end-code interpret-only

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** // should add help message to the last word ...
						1234 constant x // test!test!
						js> last().help.indexOf("test!test!") -1 != ==>judge drop
						\ see x
						(forget)
				</selftest>


code ///        ( <comment> -- ) \ Add comment to the new word, it appears in 'see'.
                var ss = nexttoken('\n|\r');
				// ss = ss.replace(/(\s*(\n|\r))|(\s+$)/gm,'\n'); // trim tailing white spaces
				ss = ss.replace(/^/,"\t"); // Add leading \t to each line.
				ss = ss.replace(/\s*$/,'\n'); // trim tailing white spaces
                last().comment = typeof(last().comment) == "undefined" ? ss : last().comment + ss;
                end-code interpret-only

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** /// should add comment to the last word ...
						1234 constant x
						/// comment line 111
						/// comment line 222
						\ see x
						<js> last().comment.indexOf("comment line 111") </jsV> -1 !=
						<js> last().comment.indexOf("comment line 222") </jsV> -1 !=
						and ==>judge drop
						(forget)
				</selftest>

code (space)    push(" ") end-code // ( -- " " ) Put a space on TOS.

				<selftest>
					*** (space) puts a 0x20 on TOS ...
						(space) js> String.fromCharCode(32) = ==>judge drop
				</selftest>

code BL         push("\\s") end-code // ( -- "\s" ) RegEx white space.

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** BL should return the string '\s' literally ...
						BL char \s = ==>judge drop
				</selftest>

code CR 		push("\n") end-code // ( -- '\n' ) NewLine is ASCII 10(0x0A)
				/// Also String.fromCharCode(10) in JavaScript

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** CR should return a new line character ...
						CR js> String.fromCharCode(10) = ==>judge drop
				</selftest>

code jsEval 	( <string> -- result ) \ Evaluate the given JavaScript statements, return the last statement's value.
                try {
                  push(eval(pop()));
                } catch(err) {
                  panic("JavaScript error : "+err.message+"\n", "error");
                };
				end-code
				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** jsEval should eval(tos) and return the last statement's value ...
						char 123 jsEval 123 ( .s ) = ==>judge drop
				</selftest>

code jsEvalNo 	( <string> -- ) \ Evaluate the given JavaScript statements, w/o return value.
                try {
                  eval(pop());
                } catch(err) {
                  panic("JavaScript error : "+err.message+"\n", "error");
                };
                end-code

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** jsEvalNo should eval(tos) but won't return any value ...
						456 char 123 jsEvalNo 456 ( .s ) = ==>judge drop
				</selftest>

code jsFunc		( "statements" -- function ) \ Compile JavaScript to a function() that returns last statement
				var ss=pop();
				ss = ss.replace(/(^( |\t)*)|(( |\t)*$)/gm,''); // remove 頭尾 white spaces
				ss = ss.replace(/\s*\/\/.*$/gm,''); // remove // comments
				ss = ss.replace(/(\n|\r)*/gm,''); // merge to one line
				ss = ss.replace(/\s*\/\*.*?\*\/\s*/gm,''); // remove /* */ comments
				ss = ss.replace(/;*\s*$/,''); // remove ending ';' from the last statement
				var parsed=ss.match(/^(.*;)(.*)$/); // [entire string,fore part,last statement]|NULL
				if (parsed){
					eval("push(function(){" + parsed[1] + "push(" + parsed[2] + ")})");
				}else{
					eval("push(function(){push(" + ss + ")})");
				}
				end-code
				
code jsFuncNo	( "statements" -- function ) \ Compile JavaScript to a function()
				eval("push(function(){" + pop() + "})"); 
				end-code

code [          compiling=false end-code immediate // ( -- ) 進入直譯狀態, 輸入指令將會直接執行 *** 20111224 sam
code ]          compiling=true end-code // ( -- ) 進入編譯狀態, 輸入指令將會編碼到系統 dictionary *** 20111224 sam
code compiling  push(compiling) end-code // ( -- boolean ) Get system state
code last 		push(last()) end-code // ( -- word ) Get the word that was last defined.

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** last should return the recent forth VM state ...
						: dummy ; last js> pop().name char dummy = ==>judge drop
						(forget)
				</selftest>

code exit       ( -- ) \ Exit this colon word.
				dictcompile(EXIT) end-code immediate compile-only

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** exit should stop a colon word ...
						: dummy 123 exit 456 ;
						last execute 123 = ==>judge drop
						(forget)
				</selftest>

code ret        ( -- ) \ Mark at the end of a colon word.
				dictcompile(RET) end-code immediate compile-only

code rescan-word-hash ( -- ) \ Rescan all word-lists in the order[] to rebuild wordhash{}
				wordhash = {};
				for (var j=0; j<order.length; j++) { // 越後面的 priority 越高
					for (var i=1; i<words[order[j]].length; i++){  // 從舊到新，以新蓋舊,重建 wordhash{} hash table.
						if (compiling) if (last()==words[order[j]][i]) continue; // skip the last() avoid of an unexpected 'reveal'.
						wordhash[words[order[j]][i].name] = words[order[j]][i];
					}
				}
				end-code
				/// Used in (forget) and vocabulary words.

code (forget) 	( -- ) \ Forget the last word
				if (last().cfa) here = last().cfa;
				words[current].pop(); // drop the last word
				execute("rescan-word-hash");
				end-code

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** (forget) should forget the last word ...
						: dummy ; (forget)
						last js> pop().name char dummy !=
					==>judge [if]
						<js> tick('rescan-word-hash').selftest='pass' </js> \ test /js
						<js> push(tick('rescan-word-hash').selftest=='pass') </jsN> \ test jsN  true
						<js> push(pop()==true) </jsN> \ test jsn  true
						[if] <js> ['</'+'js>', '</'+'jsN>'] </jsV> all-pass [then]
					[then]
				</selftest>

code :          ( <name> -- ) \ Begin a forth colon definition.
                newname = nexttoken();
                newhelp = newname + " " + packhelp(); // help messages packed
				push(newname); execute("(create)"); // 故 colon definition 裡有 last or last() 可用來取得本身。
                compiling=true;
				stackwas = stack.slice(0); // Should not be changed, ';' will check.
				last().type = "colon";
				last().cfa = here;
				last().help = newhelp;
				last().xt = colonxt = function(){
					rstack.push(ip);
					inner(this.cfa);
				}
                end-code

code ;          ( -- ) \ End of the colon definition.
                if (!g.isSameArray(stackwas,stack)) {
                    panic("Stack changed during colon definition, it must be a mistake!\n", "error");
					words[current].pop();
                } else {
					dictcompile(RET);
                }
                compiling = false;
				execute('reveal');
                end-code immediate compile-only

				<selftest>
					js: tick(':').selftest='pass'
					js: tick(';').selftest='pass'
				</selftest>

code (')		( "name" -- Word ) \ name>Word like tick but the name is from TOS.
				push(tick(pop())) end-code

code '         	( <name> -- Word ) \ Tick, get word name from TIB, leave the Word object on TOS.
				push(tick(nexttoken())) end-code

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** ' tick should return the word object ...
						: dummy ;
						' dummy js> pop().name char dummy = ==>judge [if] js> ["(')"] all-pass [then]
						(forget)
				</selftest>

code 			#tib push(ntib) end-code // ( -- n ) Get ntib
code 			#tib! ntib = pop() end-code // ( n -- ) Set ntib

\ ------------------ eforth code words ----------------------------------------------------------------------

code branch     ip=dictionary[ip] end-code compile-only // ( -- ) 將當前 ip 內數值當作 ip *** 20111224 sam

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					marker ---
					*** branch should jump to run hello ...
						: sum 0 1 begin 2dup + -rot nip 1+ dup 10 > if drop exit then again ;
						: test sum 55 = ;
						test ==>judge
					[if] <js> ['2dup', '-rot', 'nip', '1+', '>', '0branch'] </jsV> all-pass [then]
					\ cr see sum cr
					---
				</selftest>

code 0branch    if(pop())ip++;else ip=dictionary[ip] end-code compile-only // ( n -- ) 若 n!==0 就將當前 ip 內數值當作 ip, 否則將 ip 進位 *** 20111224 sam
code !          dictionary[pop()]=pop() end-code // ( n a -- ) 將 n 存入位址 a
code @          push(dictionary[pop()]) end-code // ( a -- n ) 從位址 a 取出 n
code >r         rstack.push(pop()) end-code  // ( n -- ) Push n into the return stack.
code r>         push(rstack.pop()) end-code  // ( -- n ) Pop the return stack
code r@         push(rstack[rstack.length-1 ]) end-code // ( -- r0 ) Get a copy of the TOS of return stack
code drop       pop(); end-code // ( x -- ) Remove TOS.
code dup        push(tos()); end-code // ( a -- a a ) Duplicate TOS.
code swap       var t=stack.length-1;var b=stack[t];stack[t]=stack[t-1];stack[t-1]=b end-code // ( a b -- b a ) stack operation
code over       push(stack[stack.length-2]); end-code // ( a b -- a b a ) Stack operation.
code 0<         push(pop()<0) end-code // ( a -- f ) 比較 a 是否小於 0

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					marker ---
					*** ! @ >r r> r@ drop dup swap over 0< ...
					variable x 123 x ! x @ 123 = \ true
					111 dup >r r@ r> + swap 2 * = and \ true
					333 444 drop 333 = and \ true
					555 666 swap 555 = \ true 666 true
					rot and swap \ true 666
					0< not and \ true
					-1 0< and \ true
					false over \ true
					==>judge
					[if] <js> ['!', '@', '>r', 'r>', 'r@', 'swap', 'drop',
					'dup', 'over', '0<', '2drop'] </jsV> all-pass [then]
					2drop
					---
				</selftest>

code here!      here=pop() end-code // ( a -- ) 設定系統 dictionary 編碼位址
code here       push(here) end-code // ( -- a ) 系統 dictionary 編碼位址 a

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					marker ~~~
					*** here! here ...
						marker ---
							10000 here!
							here 10000 = \ true
							: dummy ; ' dummy js> pop().cfa 10000 >= and \ true
						---
						: dummy ; ' dummy js> pop().cfa 888 < and \ true
						==>judge
						[if] <js> ['here', 'here!'] </jsV> all-pass [then]
					~~~
				</selftest>

\ JavaScript logical operations can be confusing
\ 在處理邏輯 operator 時我決定用 JavaScript 自己的 Boolean() 來 logicalize 所有的
\ operands, 這類共有 and or not 三者。為了保留 JavaScript && || 的功能 (邏輯一旦確
\ 立隨即傳回該 operand 之值) 另外定義 && || 遵照之，結果變成很奇特的功能。Forth 傳
\ 統的 AND OR NOT XOR 是 bitwise operators, 正好用傳統的大寫給它們。

code boolean    push(Boolean(pop())) end-code // ( x -- boolean(x) ) Cast TOS to boolean.
code and        var b=pop(),a=pop();push(Boolean(a)&&Boolean(b)) end-code // ( a b == a and b ) Logical and. See also '&&' and 'AND'.
code or         var b=pop(),a=pop();push(Boolean(a)||Boolean(b)) end-code // ( a b == a or b ) Logical or. See also '||' and 'OR'.
code not        push(!Boolean(pop())) end-code // ( x == !x ) Logical not. Capital NOT is for bitwise.
code &&         push(pop(1)&&pop()) end-code // ( a b == a && b ) if a then b else swap endif
code ||         push(pop(1)||pop()) end-code // ( a b == a || b ) if a then swap else b endif
code AND        push(pop() & pop()) end-code // ( a b -- a & b ) Bitwise AND. See also 'and' and '&&'.
code OR         push(pop() | pop()) end-code // ( a b -- a | b ) Bitwise OR. See also 'or' and '||'.
code NOT        push(~pop()) end-code // ( a -- ~a ) Bitwise NOT. Small 'not' is for logical.
code XOR        push(pop() ^ pop()) end-code // ( a b -- a ^ b ) Bitwise exclusive OR.
code true       push(true) end-code // ( -- true ) boolean true.
code false      push(false) end-code // ( -- false ) boolean false.
code ""         push("") end-code // ( -- "" ) empty string.
code []         push([]) end-code // ( -- [] ) empty array.
code {}         push({}) end-code // ( -- {} ) empty object.
code undefined  push(undefined) end-code // ( -- undefined ) Get an undefined value.
code null		push(null) end-code // ( -- null ) Get a null value.
				/// 'Null' can be used in functions to check whether an argument is given.

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** boolean and or && || not AND OR NOT XOR ...
					undefined not \ true
					"" boolean \ true false
					and \ false
					false and \ false
					false or \ false
					true or \ true
					true and \ true
					true or \ true
					false or \ true
					{} [] || \ true [] {}
					&& \ true []
					|| \ [] true
					&& \ true
					"" && \ true ""
					not \ false
					1 2 AND \ true 0
					2 OR NOT  \ true -3
					-3 = \ true true
					1 2 XOR \ true true 3
					0 XOR 3 = \ true true true
					and and \ true
					<js> function test(x){ return x }; test() </jsV> null = \ true true
					and ==>judge
					[if] <js> ['and', 'or', 'not', '||', '&&', 'AND', 'OR', 'NOT', 'XOR',
						  'true', 'false', '""', '[]', '{}', 'undefined', 'boolean', 'null'
					] </jsV> all-pass [then]
				</selftest>

\ Not eforth code words
\ 以下照理都可以用 eforth 的基本 code words 組合而成 colon words, 我覺得 jeforth 裡適合用 code word 來定義。

code +          push(pop(1)+pop()) end-code // ( a b -- a+b) Add two numbers or concatenate two strings.
code *          push(pop()*pop()) end-code // ( a b -- a*b ) Multiplex.
code -          push(pop(1)-pop()) end-code // ( a b -- a-b ) a-b
code /          push(pop(1)/pop()) end-code // ( a b -- c ) 計算 a 與 b 兩數相除的商 c
code 1+         push(pop()+1) end-code // ( a -- a++ ) a += 1
code 2+         push(pop()+2) end-code // ( a -- a+2 )
code 1-         push(pop()-1) end-code // ( a -- a-1 ) TOS - 1
code 2-         push(pop()-2) end-code // ( a -- a-2 ) TOS - 2

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** + * - / 1+ 2+ 1- 2- ...
					1 1 + 2 * 1 - 3 / 1+ 2+ 1- 2- 1 = ==>judge
					[if] <js> ['+', '*', '-', '/', '1+', '2+', '1-', '2-'] </jsV> all-pass [then]
				</selftest>

code mod        push(pop(1)%pop()) end-code // ( a b -- c ) 計算 a 與 b 兩數相除的餘 c
code div        var b=pop();var a=pop();push((a-(a%b))/b) end-code // ( a b -- c ) 計算 a 與 b 兩數相除的整數商 c

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** mod 7 mod 3 is 1 ...
						7 3 mod 1 = ==>judge drop
					*** div 7 div 3 is 2 ...
						7 3 div 2 = ==>judge drop
				</selftest>

code >>         var n=pop();push(pop()>>n) end-code // ( data n -- data>>n ) Singed right shift
code <<         var n=pop();push(pop()<<n) end-code // ( data n -- data<<n ) Singed left shift
code >>>        var n=pop();push(pop()>>>n) end-code // ( data n -- data>>>n ) Unsinged right shift. Note! There's no <<<.

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** >> -1 signed right shift n times will be still -1 ...
						-1 9 >> -1 = ==>judge drop
					*** >> -4 signed right shift becomes -2 ...
						-4 1 >> -2 = ==>judge drop
					*** << -1 signed left shift 63 times become the smallest int number ...
						-1 63 << 0x80000000 -1 * = ==>judge drop
					*** >>> -1 >>> 1 become 7fffffff ...
						-1 1 >>> 0x7fffffff = ==>judge drop
				</selftest>

code 0=         push(pop()==0) end-code // ( a -- f ) 比較 a 是否等於 0
code 0>         push(pop()>0) end-code // ( a -- f ) 比較 a 是否大於 0
code 0<>        push(pop()!=0) end-code // ( a -- f ) 比較 a 是否不等於 0
code 0<=        push(pop()<=0) end-code // ( a -- f ) 比較 a 是否小於等於 0
code 0>=        push(pop()>=0) end-code // ( a -- f ) 比較 a 是否大於等於 0
code =          push(pop()==pop()) end-code // ( a b -- a=b ) 經轉換後比較 a 是否等於 b, "123" = 123.

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** 0= 0> 0<> 0 <= 0>= ...
						"" 0= \ true
						undefined 0= \ true false
						1 0> \ true false true
						0 0> \ true false true false
						XOR -rot XOR + 2 = \ true
						0<> \ false
						0= \ true
						0<> \ true
						0<= \ true
						0>= \ true
						99 && \ 99
						0= \ false
						99 || 0<> \ true
						-1 0<= \ true true
						1 0>= \ true true true
						s" 123" 123 = \ \ true true true true
						&& && && ==>judge
					[if] <js> ['0=', '0>', '0<>', '0<=', '0>=', '='] </jsV> all-pass [then]
				</selftest>

code ==         push(Boolean(pop())==Boolean(pop())) end-code // ( a b -- f ) 比較 a 與 b 的邏輯
code ===        push(pop()===pop()) end-code // ( a b -- a===b ) 比較 a 是否全等於 b
code >          var b=pop();push(pop()>b) end-code // ( a b -- f ) 比較 a 是否大於 b
code <          var b=pop(); push(pop()<b) end-code // ( a b -- f ) 比較 a 是否小於 b
code !=         push(pop()!=pop()) end-code // ( a b -- f ) 比較 a 是否不等於 b
code !==        push(pop()!==pop()) end-code // ( a b -- f ) 比較 a 是否不全等於 b
code >=         var b=pop();push(pop()>=b) end-code // ( a b -- f ) 比較 a 是否大於等於 b
code <=         var b=pop();push(pop()<=b) end-code // ( a b -- f ) 比較 a 是否小於等於 b


				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** == compares after booleanized ...
						{} [] == \ true
						"" null == \ true
						"" undefined == \ true
						s" 123" 123 == \ true
						&& && && ==>judge drop
					*** === compares the type also ...
						"" 0 = \ true
						"" 0 == \ true
						"" 0 === \ false
						s" 123" 123 = \ true
						s" 123" 123 == \ true
						s" 123" 123 === \ false
						XOR and XOR and and ==>judge drop
					*** > < >= <= != !== <> ...
						1 2 > \ false
						1 1 > \ false
						2 1 > \ true
						1 2 < \ true
						1 1 < \ false
						2 1 < \ fasle
						1 2 >= \ false
						1 1 >= \ true
						2 1 >= \ true
						1 2 <= \ true
						1 1 <= \ true
						2 1 <= \ fasle
						1 1 <> \ false
						0 1 <> \ true
						XOR AND XOR and and and XOR XOR XOR and and XOR XOR ==>judge
						[if] <js> ['<', '>=', '<=', '!=', '!==', '<>'] </jsV> all-pass [then]
				</selftest>

code abs        push(Math.abs(pop())) end-code // ( n -- |n| ) Absolute value of n.
code max        push(Math.max(pop(),pop())) end-code // ( a b -- max(a,b) ) The maximum.
code min        push(Math.min(pop(),pop())) end-code // ( a b -- min(a,b) ) The minimum.

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** abs makes negative positive ...
						1 63 << abs 0x80000000 = ==>judge drop
					*** max min ...
						1 -2 3 max max 3 = \ true
						1 -2 3 min min -2 = \ true
						and ==>judge
						[if] <js> ['min'] </jsV> all-pass [then]
				</selftest>

code doVar      push(ip); ip=rstack.pop(); end-code compile-only // ( -- a ) 取隨後位址 a , runtime of created words
code doNext     var i=rstack.pop()-1;if(i>0){ip=dictionary[ip]; rstack.push(i);}else ip++ end-code compile-only // ( ?? ) next's runtime.
code ,          dictcompile(pop()) end-code // ( n -- ) Compile TOS to dictionary.

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					marker ---
					*** doVar doNext ...
						variable x
						: tt for x @ . x @ 1+ x ! next ;
						10 tt space x @ 10 = ==>judge [if]
						<js> ['doNext','space', ',', 'colon-word', 'create',
						'for', 'next'] </jsV> all-pass
						[then]
					---
				</selftest>

\ 目前 Base 切換只影響 .r .0r 的輸出結果。
\ JavaScript 輸入用外顯的 0xFFFF 形式，用不著 hex decimal 切換。

code hex        kvm.base=16 end-code // ( -- ) 設定數值以十六進制印出 *** 20111224 sam
code decimal    kvm.base=10 end-code // ( -- ) 設定數值以十進制印出 *** 20111224 sam
code base@      push(kvm.base) end-code // ( -- n ) 取得 base 值 n *** 20111224 sam
code base!      kvm.base=pop() end-code // ( n -- ) 設定 n 為 base 值 *** 20111224 sam
10 base!        // 沒有經過宣告的 variable base 就是 kvm.base

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** hex decimal base@ base! ...
						decimal base@ 0x0A = \ true
						10 0x10 = \ false
						hex base@ 0x10 = \ true
						10 0x10 = \ false !!!! JavaScript 輸入用外顯的表達 10 就是十不會變，這好！
						0x0A base!
						base@ 10 = \ true
						XOR and XOR and ==>judge [if]
						<js> ['decimal','base@', 'base!'] </jsV> all-pass
						[then]
				</selftest>

code depth      ( -- depth ) \ Data stack depth
				push(stack.length) end-code
code pick       ( nj ... n1 n0 j -- nj ... n1 n0 nj ) \ Get a copy of a cell in stack.
				push(tos(pop())) end-code
				/// see rot -rot roll pick
code roll       ( ... n3 n2 n1 n0 3 -- ... n2 n1 n0 n3 )
				push(pop(pop())) end-code
				/// see rot -rot roll pick

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					*** pick 2 from 1 2 3 gets 1 2 3 1 ...
					1 2 3 0 pick 3 = depth 4 = and >r 3 drops \ true
					1 2 3 1 pick 2 = depth 4 = and >r 3 drops \ true
					1 2 3 2 pick 1 = depth 4 = and >r 3 drops \ true
					r> r> r> and and ==>judge drop
					*** roll 2 from 1 2 3 gets 2 3 1 ...
					1 2 3 0 roll 3 = depth 3 = and >r 2 drops \ true
					1 2 3 1 roll 2 = depth 3 = and >r 2 drops \ true
					1 2 3 2 roll 1 = depth 3 = and >r 2 drops \ true
					r> r> r> and and ==>judge drop
				</selftest>
code .          ( sth -- ) \ Print number or string on TOS.
				print(pop());
				end-code

: space      	(space) . ; // ( -- ) Print a space.

code word       ( "delimiter" -- "token" <delimiter> ) \ Get next "token" from TIB.
				push(nexttoken(pop())) end-code
				/// First character after 'word' will always be skipped first, token separator.
				/// If delimiter is RegEx '\s' then white spaces before the "token"
				/// will be removed. Otherwise, return TIB[ntib] up to but not include the delimiter.
				/// If delimiter not found then return the entire remaining TIB (can be multiple lines!).

				<selftest>
					marker ---
					*** word reads "string" from TIB ...
					char \s word    111    222 222 === >r s" 111" === r> and \ true , whitespace 會切掉
					char  2 word    111    222 222 === >r s"    111    " === r> and \ true , whitespace 照收
					: </div> ;
					char </div> word    此後到 </ div> 之
								前都被收進，可
								以跨行！ come-find-me-!!
					</div> js> pop().indexOf("come-find-me-!!")!=-1 \ true
					and and ==>judge drop
					---
				</selftest>

: [compile]     ' , ; immediate // ( <string> -- ) Compile the next immediate word.
				/// 把下個 word 當成「非立即詞」進行正常 compile, 等於是把它變成正常 word 使用。

: compile       ( -- ) \ Compile the next word at dictionary[ip] to dictionary[here].
				r> dup @ , 1+ >r ; compile-only 

				<selftest>
					marker ---
					*** [compile] compile [ ] ...
					: iii ; immediate
					: jjj ;
					: test [compile] iii compile jjj ; \ 正常執行 iii，把 jjj 放進 dictionary
					: use [ test ] ; \ 如果 jjj 是 immediate 就可以不要 [ ... ]
					' use js> pop().cfa @ ' jjj = ==>judge [if]
						<js> ['compile', '[', ']'] </jsV> all-pass
					[then]
					---
				</selftest>

code colon-word	( -- ) \ Decorate the last() as a colon word.
				// last().type = "colon";
				last().cfa = here;
				last().xt = colonxt;
				end-code

: create		( <name> -- ) \ Create a new word. The new word is a variable by default.
				BL word (create) reveal colon-word compile doVar ;

code (marker)   ( "name" -- ) \ Create marker "name". Run "name" to forget itself and all newers.
                var lengthwas = current_word_list().length; // save current word list length before create the new marker word
				execute("(create)");execute("reveal");
				last().type = "marker";
                last().herewas = here;
                last().lengthwas = lengthwas; // [x] 引進 vocabulary 之後，此 marker 在只有 forth-wordlist 時使用。有了多個 word-list 之後要改寫。
				last().help = newname + " " + packhelp(); // help messages packed
                last().xt = function(){ // marker's xt restores the saved context
                    here = this.herewas;
					order = [current = context = "forth"]; // 萬一此 marker 在引入 vocabulary 之後被 call 到。
					for(var vid in words) if(vid != current) delete words[vid]; // "forth" is the only one, clean up other word-lists.
                    words[current] = current_word_list().slice(0, this.lengthwas);
                    dictionary = dictionary.slice(0,here);
					wordhash = {};
                    for (var i=1; i<current_word_list().length; i++){  // 從舊到新，以新蓋舊,重建 wordhash{} hash table.
                        wordhash[current_word_list()[i].name] = current_word_list()[i];
                    }
                }
                end-code
: marker     	( <name> -- ) \ Create marker <name>. Run <name> to forget itself and all newers.
				BL word (marker) ;
code next       compilecode("doNext");dictionary[here++]=pop(); end-code immediate compile-only // ( -- ) for ... next (FigTaiwan SamSuanChen)

code cls		( -- ) \ Clear jeforth console screen
				kvm.screenbuffer = (kvm.screenbuffer==null) ? null : "";
				kvm.clearScreen();
				end-code
code abort      reset() end-code // ( -- ) Reset the forth system.

code literal 	( n -- ) \ Compile TOS as an anonymous constant
				var literal = pop();
				var getLiteral = eval("var f;f=function(){push(literal)/*(" + mytypeof(literal) + ")" + literal.toString() + " */}");
				dictcompile(getLiteral);
				end-code
code alias      ( Word <alias> -- ) \ Create a new name for an existing word
				var w = pop();
				// To use the correct TIB, must use execute("word") instead of fortheval("word").
				execute("BL"); execute("word"); execute("(create)");execute("reveal");
                // mergeObj(last(), w); // copy everything by value from the predecessor includes arrays and objects.
				for(var i in w) last()[i] = w[i]; // copy from predecessor but arrays and objects are by reference
				last().predecessor = last().name;
                last().name = newname;
				last().type = "alias";
                end-code

				<selftest>
					depth [if] .( Data stack should be empty! ) cr \s [then]
					marker ---
					*** alias should create a new word that acts same ...
						1234 constant x ' x alias y
						y 1234 = ==>judge drop
						\ see x cr see y
					---
				</selftest>

\ ------------------ eforth colon words ---------------------------

' != alias <>	// ( a b -- f ) 比較 a 是否不等於 b, alias of !=.
' \s alias stop // ( -- ) Samething as \s, stop outer loop hopefully stop everything.
code nip		pop(1) end-code // ( a b -- b ) 
code rot		push(pop(2)) end-code // ( w1 w2 w3 -- w2 w3 w1 ) 
				/// see rot -rot roll pick
code -rot		push(pop(),1) end-code // ( w1 w2 w3 -- w3 w1 w2 ) 
				/// see rot -rot roll pick
code 2drop		stack.splice(stack.length-2,2) end-code // ( ... a b -- ... )
: 2dup          ( w1 w2 -- w1 w2 w1 w2 ) over over ;
' NOT alias invert // ( w -- ~w )
: negate        -1 * ; // ( n -- -n ) Negated TOS.
: within         ( n low high -- within? ) -rot over max -rot min = ;

				<selftest>
					*** nip rot -rot 2drop 2dup invert negate within ...
					1 2 3 4 nip \ 1 2 4
					-rot \ 4 1 2
					2drop \ 4
					3 2dup \ 4 3 4 3
					invert negate \ 4 3 4 4
					= rot rot \ true 4 3
					5 within \ true true
					1 2 3 within \ true true false
					4 2 3 within \ true true false false
					-2 -4 -1 within \ true true false false true
					0 -4 -1 within \ true true false false true false
					-5 -4 -1 within \ true true false false true false false
					XOR XOR XOR XOR XOR XOR
					==>judge [if]
						<js> ['rot', '-rot', '2drop', '2dup', 'negate', 'invert', 'within'] </jsV> all-pass
					[then]
				</selftest>

: [']			( <name> -- Word ) \ In colon definitions, compile next word object as a literal.
				' literal ; immediate compile-only

				<selftest>
					marker ---
					*** ['] tick next word immediately ...
					: x ;
					: test ['] x ;
					test ' x = ==>judge drop
					---
				</selftest>

: allot         here + here! ; // ( n -- ) 增加 n cells 擴充 memory 區塊

				<selftest>
					marker ---
					*** allot should consume some dictionary cells ...
					: a ; : b ; ' b js> pop().cfa ' a js> pop().cfa - \ normal distance
					: aa ;
					10 allot
					: bb ; ' bb js> pop().cfa ' aa js> pop().cfa - \ 10 more expected
					- abs 10 = ==>judge drop
					---
				</selftest>

: for           ( count -- ) \ for..next loop.
				compile >r here ; immediate compile-only
				/// for ... next (count ... 2,1) but when count <= 0 still do once!!
				/// for aft ... then next (count-1 ... 2,1) but do nothing if count <= 1.
				/// : test 5 for r@ . space next ; test ==> 5 4 3 2 1
				/// : test 5 for 5 r@ - . space next ; test ==> 0 1 2 3 4 
				/// : test dup for dup r@ - . space next drop ; 5 test ==> 0 1 2 3 4 
				/// : test 10 for 10 r@ - dup . space 5 >= if r> drop 0 >r then next ; test
				/// ==> 0 1 2 3 4 5 , "r> drop 0 >r" is leave/exit/terminate of for..next loop
				
: begin         ( -- a ) \ begin..again, begin..until, begin..while..until..then, begin..while..repeat
				here ; immediate compile-only
: until         ( a -- ) \ begin..unitl
				compile 0branch , ; immediate compile-only
: again         ( a -- ) \ begin..again,
				compile  branch , ; immediate compile-only

				<selftest>
					marker ---
					*** begin again , begin until ...
					: tt
						1 0 \ index sum
						begin \ index sum
							over \ index sum index
							+ \ index sum'
							swap 1+ \ sum' index'
							dup 10 > if \ sum' index'
								drop
								exit
							then  \ sum' index'
							swap  \ index' sum'
						again
					; last execute 55 = \ true
					: ttt
						1 0 \ index sum
						begin \ index sum
							over \ index sum index
							+ \ index sum'
							swap 1+ \ sum' index'
							swap \ index' sum'
						over 10 > until \ index' sum'
						nip
					; last execute 55 = \ true
					and ==>judge [if]
					<js> ['again', 'until', 'over', 'swap', 'dup', 'exit', 'nip'] </jsV> all-pass
					[then]
					---
				</selftest>

: if            ( -- a ) \ if..then..else
				compile 0branch here 0 , ; immediate compile-only
: ahead         ( -- a ) \ aft internal use
				compile branch here 0 , ; immediate compile-only
' ahead alias never immediate compile-only // ( -- a ) never ... then for call-back entry inner(word.cfa+n) 
: repeat        ( a a -- ) \ begin..while..repeat
				[compile] again here swap ! ; immediate compile-only
: then          ( a -- ) \ if..then..else
				here swap ! ; immediate compile-only
: aft           ( a -- a a ) \ for aft ... then next
				drop [compile] ahead [compile] begin swap ; immediate compile-only
: else          ( a -- a ) \ if..then..else
				[compile] ahead swap [compile] then ; immediate compile-only
: while         ( a -- a a ) \ begin..while..repeat
				[compile] if swap ; immediate compile-only

				<selftest>
					marker ---
					*** aft for then next ahead begin while repeat ...
					: tt 5 for r@ next ; last execute + + + + 15 = \ true
					: ttt 5 for aft r@ then next ; last execute + + + 10 = \ true true
					depth 2 = \ T T T
					: tttt
						0 0 \ index sum
						begin \ idx sum
							over 10 <=
						while \ idx sum
							over +
							swap 1+ swap
						repeat \ idx sum
						nip
					; last execute 55 = \ T T T T
					and and and ==>judge [if]
					<js> ['for', 'then', 'next', 'ahead', 'begin', 'while', 'repeat'] </jsV> all-pass
					[then]
					---
				</selftest>

: char          ( <str> -- str ) \ Get character(s).
				BL word compiling if literal then ; immediate
				/// "char abc" gets "abc", Note! ANS forth "char abc" gets only 'a'.

: ?dup          dup if dup then ; // ( w -- w w | 0 ) Dup TOS if it is not 0|""|false.

				<selftest>
					*** ?dup dup only when it's true ...
					1 0 ?dup \ 1 0
					drop ?dup \ 1 1
					+ 2 = ==>judge drop
				</selftest>

: variable      ( <string> -- ) \ Create a variable.
				create 0 , [ char push(function(){last().type='colon-variable'}) jsEvalNo , ] ;
				
: +!            ( n addr -- ) \ Add n into addr, addr is a variable.
				swap over @ swap + swap ! ;
: ?             @ . ; // ( a -- ) print value of the variable.

				<selftest>
					marker ---
					*** +! ? variable ...
					variable x 10 x !
					5 x +! x @ 15 = \ true
					x ? space <js> kvm.screenbuffer.slice(-3)=='15 '</jsV> \ true true
					and ==>judge [if]
					<js> ['variable', 'marker', '?', 'space'] </jsV> all-pass
					[then]
					---
				</selftest>

: chars         ( n str -- ) \ Print str n times.
				swap 0 max dup 0= if exit then for dup . next drop ;

: spaces        ( n -- ) \ print n spaces.
				(space) chars ;

				<selftest>
					marker ---
					*** spaces chars ...
					: test 3 spaces ;
					test
					<js> kvm.screenbuffer.slice(-3)=='   '</jsV>
					==>judge [if]
					<js> ['chars'] </jsV> all-pass
					[then]
					---
				</selftest>

: .(            char \) word . BL word drop ; immediate // ( <str> -- ) Print following string down to ')' immediately.
: ."			( <str> -- ) \ Print following string down to '"'.
				char " word compiling if literal compile .
				else . then BL word drop ; immediate
				\ 本來是 compile-only, 改成都可以。 hcchen5600 2014/07/17 16:40:04
: .'            ( <str> -- ) \ Print following string down to "'".
				char ' word compiling if literal compile .
				else . then BL word drop ; immediate
				\ 本來是 compile-only, 改成都可以。 hcchen5600 2014/07/17 16:40:04
: s"  			( <str> -- str ) \ Get string down to the next delimiter.
				char " word compiling if literal then BL word drop ; immediate
: s'  			( <str> -- str ) \ Get string down to the next delimiter.
				char ' word compiling if literal then BL word drop ; immediate
: s`  			( <str> -- str ) \ Get string down to the next delimiter.
				char ` word compiling if literal then BL word drop ; immediate
: does>         ( -- ) \ redirect the last new colon word.xt to after does>
				[compile] ret \ dummy 'ret' mark for 'see' to know where is the end of a creat-does word
				r> [ s" push(function(){push(last().cfa)})" jsEvalNo , ] ! ; 

				<selftest>
					marker ---
					*** .( ( ." .' s" s' s` ...
					selftest-invisible
					.( aa) ( now kvm.screenbuffer should be 'aa' )
					js> kvm.screenbuffer.slice(-2)=="aa" \ true
					: test ." aa" .' bb' s' cc' . s` dd` . s" ee" . ;
					test
					selftest-visible
					js> kvm.screenbuffer.slice(-10)=="aabbccddee" \ true
					and
					==>judge [if]
					<js> ['(', '."', ".'", "s'", "s`", 's"', 'does>'] </jsV> all-pass
					[then]
					---
				</selftest>

: count 		( string -- string length ) \ Get length of the given string
				[ s" push(function(){push(tos().length)})" jsEvalNo , ] ;

				<selftest>
					*** count ...
						s" abc" count 3 = swap \ true "abc"
						depth 2 = \ true "abc" true
						and and ==>judge drop
				</selftest>

code accept		push(false) end-code // ( -- str T|F ) Read a line from terminal. A fake before I/O ready.
: refill        ( -- flag ) \ Reload TIB from stdin. return 0 means no input or EOF
				accept if [ s" push(function(){tib=pop();ntib=0})" jsEvalNo , ] 1 else 0 then ;

: [else] ( -- ) \ 考慮中間的 nested 結構，把下一個 [then] 之前的東西都丟掉。
				1
				begin \ level
					begin \ level
						BL word count \ (level $word len ) 吃掉下一個 word
					while \ (level $word) 查看這個被吃掉的 word
						dup s" [if]" = if \ level $word
							drop 1+ \ level' 如果這個 word 是 [if] 就要多出現一個 [then] 之後才結束
						else \ level $word
							dup s" [else]" = if \ (level)
								drop 1- dup if 1+ then \ (level') 這個看不太懂，似乎是如果最外層多出一個 [else] 就把它當 [then] 用。
							else \ level $word
								s" [then]" = if \ (level)
									1- \ level' \ (level') 如果這個 word 是 [then] 就剝掉一層
								then \ (level') 其他 word 吃掉就算了
							then \ level'
						then \ level'
						?dup if else exit then \ (level') 這個 [then] 是最外層就整個結束，否則繼續吃掉下一個 word.
					repeat \ (level) or (level $word)
					drop   \ (level)
				refill not until \ level
				drop
				; immediate
: [if] 			( flag -- ) \ Conditional compilation [if] [else] [then]
				if else [compile] [else] then \ skip everything down to [else] or [then] when flag is not true.
				; immediate
: [then] 		( -- ) \ Conditional compilation [if] [else] [then]
				; immediate
: js>  			( <expression> -- value ) \ Evaluate JavaScript <expression> which has no white space within.
				BL word compiling if jsFunc , else jsEval then  ; immediate
				/// Same thing as "s' blablabla' jsEval" but simpler. Return the last statement's value.
: js:  			( <expression> -- ) \ Evaluate JavaScript <expression> which has no white space within
				BL word compiling if jsFuncNo , else jsEvalNo then  ; immediate
				/// Same thing as "s' blablabla' jsEvalNo" but simpler. No return value.
: ::  			( obj <foo.bar> ) \ Simplified form of "obj js: pop().foo.bar" w/o return value
				BL word js> tos().charAt(0)=='['||tos().charAt(0)=='(' if char pop() else  char pop(). then 
				swap + compiling if jsFuncNo , else jsEvalNo then ; immediate
: :> 			( obj <foo.bar> ) \ Simplified form of "obj js> pop().foo.bar" w/return value
				BL word js> tos().charAt(0)=='['||tos().charAt(0)=='(' if char pop() else  char pop(). then 
				swap + compiling if jsFunc , else jsEval then ; immediate
: (				( <str> -- ) \ Ignore the comment down to ')', can be nested but must be balanced
				js> nextstring(/\(|\)/).str \ word 固定會吃掉第一個 character 故不適用。
				drop js> tib[ntib++] \ 撞到停下來的字母非 '(' 即 ')' 要不就是行尾，都可以 skip 過去
				char ( = if \ 剛才那個字母是啥？
					[ last literal ] dup \ 取得本身
					execute \ recurse nested level
					execute \ recurse 剩下來的部分
				then ; immediate 

				<selftest>
					marker -%-%-%-%-%-
					**** value and to work together ...
					112233 value x x 112233 = \ true
					445566 to x x 445566 = \ true
					: test 778899 to x ; test x 778899 = \ true
					and and ==>judge [if] <js> [
					'value','to'
					] </jsV> all-pass [else] *debug* selftest-failed->>> [then]
					-%-%-%-%-%-
				</selftest>

: "msg"abort	( "errormsg" -- ) \ Panic with error message and abort the forth VM
				js: panic(pop()+'\n') abort ;

: abort"		( <msg>	-- ) \ Through an error message and abort the forth VM
				char " word literal BL word drop compile "msg"abort ;
				immediate compile-only

: "msg"?abort	( "errormsg" flag -- ) \ Conditional panic with error message and abort the forth VM
                if "msg"abort else drop then ;

: ?abort"       ( f <errormsg> -- ) \ Conditional abort with an error message.
                char " word literal BL word drop
				compile swap compile "msg"?abort ;
				immediate compile-only

\ 其實所有用 word 取 TIB input string 的 words， 用 file 或 clipboard 輸入時， 都是可
\ 以跨行的！只差用 keyboard 輸入時受限於 console input 一般都是以「行」為單位的，造成
\ TIB 只能到行尾為止後面沒了，所以才會跨不了行。將來要讓 keyboard 輸入也能跨行時，就
\ 用 text。

: <text>		( <text> -- "text" ) \ Get multiple-line string
				char </text> word ; immediate

: </text> 		( "text" -- ... ) \ Delimiter of <text>
				compiling if literal then ; immediate
				/// Usage: <text> word of multiple lines </text>

: <comment>		( <comemnt> -- ) \ Can be nested
				[ last literal ] :: level+=1 char <comment>|</comment> word drop 
				; immediate last :: level=0

: </comment>	( -- ) \ Can be nested
				['] <comment> js> tos().level>1 swap ( -- flag obj )
				js: tos().level=Math.max(0,pop().level-2) \ 一律減一，再預減一餵給下面加回來
				( -- flag ) if [compile] <comment> then ; immediate 

				<selftest>
					**** <comment>...</comment> can be nested now ... 
					<comment> 
						aaaa <comment> bbbbbb </comment> cccccc 
					</comment> 
					111 222 <comment> 333 </comment> 444
					444 = swap 222 = and swap 111 = and ==>judge [if] 
					<js> ['<comment>', '</comment>', '::'] </jsV> all-pass [then]
				</selftest>
				
: <js> 			( <js statements> -- "statements" ) \ Evaluate JavaScript statements
				char </js>|</jsV>|</jsN>|</jsRaw> word ; immediate

: </jsN> 		( "statements" -- ) \ No return value
				compiling if jsFuncNo , else jsEvalNo then ; immediate
				/// 可以用來組合 JavaScript function
				last alias </js>  immediate

: </jsV> 		( "statements" -- ) \ Retrun the value of last statement
				compiling if jsFunc , else jsEval then ; immediate
				/// 可以用來組合 JavaScript function

: constant 		( n <name> -- ) \ Create a 'constnat', Don't use " in <name>.
				BL word (create) <js> 
				last().type = "constant";
				var s = 'var f;f=function(){push(g["' 
						+ last().name 
						+ '"])}';
				last().xt = eval(s);
				g[last().name] = pop();
				</js> reveal ; 
: value 		( n <name> -- ) \ Create a 'value' variable, Don't use " in <name>.
				constant last :: type='value' ; 
: to 			( n <value> -- ) \ Assign n to <value>.
				' ( word ) <js> if (tos().type!="value") panic("Error! Assigning to a none-value.\n",'error') </js>
				compiling if ( word ) 
					<js> var s='var f;f=function(){/* to */ g["'+pop().name+'"]=pop()}';push(eval(s))</js> ( f ) ,
				else ( n word )
					js: g[pop().name]=pop()
				then ; immediate
				
				<selftest>
					marker ---
					*** constant value and to ... 
					112233 constant x
					x value y
					x y = \ true
					332211 to y x y = \ false
					' x :> type=="constant" \ true
					' y :> type=="value" \ true
					and swap not and and ==>judge drop
					---
				</selftest>

: sleep 		( mS -- ) \ Suspend to idle, resume after mS. Can be 'stopSleeping'.
				[ last literal ] ( mS me )
				<js>
					function resume() { 
						if (!me.timeoutId) return; // 萬一想提前結束時其實已經 timeout 過了則不做事。
						delete(g.setTimeout.registered()[me.timeoutId.toString()]);
						tib = tibwas; ntib = ntibwas; me.timeoutId = null;
						outer(ipwas); // resume to the below ending 'ret' and then go through the TIB.
					}
					var tibwas=tib, ntibwas=ntib, ipwas=ip, me=pop(), delay=pop();
					me.resume = resume; // So resume can be triggered from outside
					if (me.timeoutId) {
						panic("Error! double 'sleep' not allowed, use 'nap' instead.\n",true)
					} else {
						tib = ""; ntib = ip = 0; // ip = 0 reserve rstack, suspend the forth VM 
						me.timeoutId = g.setTimeout(resume,delay);
					}
				</js> ;
				/// 為了要能 stopSleeping 引入了 sleep.timeoutId 致使多重 sleeping 必須禁止。
				/// 另設有不可中止的 nap 命令可以多重 nap.

code stopSleeping ( -- ) \ Resume forth VM sleeping state, opposite of the sleep command.
				clearTimeout(tick('sleep').timeoutId);
				tick('sleep').resume();
				end-code

: nap			( mS -- ) \ Suspend to idle, resume after mS. Multiple nap is allowed.
				<js>
					var tibwas=tib, ntibwas=ntib, ipwas=ip, delay=pop();
					tib = ""; ntib = ip = 0; // ip = 0 reserve rstack, suspend the forth VM 
					// setTimeout(resume,delay);
					var timeoutId = g.setTimeout(resume,delay);
					function resume() { 
						delete(g.setTimeout.registered()[timeoutId.toString()]);
						tib = tibwas; ntib = ntibwas;
						outer(ipwas); // resume to the below ending 'ret' and then go through the TIB.
					}
				</js> ;
				/// nap 不用 g.setTimeout 故不能中止，也不會堆積在 g.setTimeout.registered() 裡。

: cr         	js: print("\n") ; // ( -- ) 到下一列繼續輸出 *** 20111224 sam
				\ 個別 quit.f 裡重定義成 : cr js: print("\n") 1 nap js: jump2endofinputbox.click() ;

code cut		( -- ) \ Cut off used TIB.
				tib=tib.slice(ntib);ntib=0 end-code
				/// cut . . rewind TIB 不斷重複, 'stop' to break it.

: -word 		( -- array[] ) \ Get TIB used tokens.
				<js> var a=('h '+tib.substr(0,ntib)+' t').split(/\s+/); // 加上 dummy 頭尾再 split 以統一所有狀況。
				a.pop(); a.shift(); /* 丟掉 dummy 頭尾巴 */ a</jsV> ;
				/// 跟 word 有點相反的味道，故以 -word 為名。

: rewind		( -- ) \ Rewind TIB so as to repeat it. 
				-word <js> var a=pop(),flag=false; for(var i in a) flag = flag || a[i]=='nap'; flag </jsV>
				not ?abort" Warning! no 'nap' in command line, suspecious of infinit loop." js: ntib=0 ;
				/// cut ~ rewind TIB 不斷重複, 'stop' to break it.
				
\ ------------------ jsc JavaScript console debugger  --------------------------------------------
\ jeforth.f is common for all applications. jsc is application dependent. So the definition of 
\ kvm.jsc.xt has been moved to quit.f of each application for propritary treatments.
\ The initial module of each application, e.g. jeforth.hta and jeforth.htm, should provide a dummy 
\ kvm.jsc.xt before quit.f being available.
\
\ Usage:
\   Put this line,
\     if(kvm.debug){kvm.jsc.prompt="msg";eval(kvm.jsc.xt)}
\   among JavaScript code as a break point. The "msg" shows you which break point is triggered.
\
\	Example:
\	Debugger can see variables aa, bb, and input in below example.
\
\	<js>
\		function test (input) {
\			var aa = 11;
\			var bb = 22;
\	if(1){kvm.jsc.prompt="bp1>>>";eval(kvm.jsc.xt)}
\		}
\		test(33);
\	</js>
\

: jsc			( -- ) \ JavaScript console usage: js: kvm.jsc.prompt="111>>>";eval(kvm.jsc.xt)
				cr ." J a v a S c r i p t   C o n s o l e" cr
				." Usage: js: if(kvm.debug){kvm.jsc.prompt='msg';eval(kvm.jsc.xt)}" cr
				js: if(1){kvm.jsc.prompt="jsc>";eval(kvm.jsc.xt)}
				;

\ ------------------ Tools  ----------------------------------------------------------------------

: int 			( float -- integer )
				js> parseInt(pop()) ;

				<selftest>
					*** int 3.14 is 3, 12.34AB is 12 ...
					3.14 int 3 =
					char 12.34AB int 12 =
					and
					==>judge drop
				</selftest>

: random 		( -- 0~1 )
				js> Math.random() ;

				<selftest>
					*** random is (0...1) ...
					random 0 > random 1 < and
					random 0 > random 1 < and
					random 0 > random 1 < and
					random 0 > random 1 < and
					and and and ==>judge drop
				</selftest>

: nop 			; // ( -- ) No operation.

				<selftest>
					*** nop does nothing ...
					nop
					true ==>judge drop
				</selftest>

: drops 		( ... n -- ... ) \ Drop n cells from data stack.
				1+ js> stack.splice(stack.length-tos(),pop()) drop ;
				/// We need 'drops' <js> sections in a colon definition are easily to have
				/// many input arguments that need to be dropped.

				<selftest>
					*** drops n data stack cells ...
						1 2 3 4 5 2 drops depth 3 = ==>judge 4 drops
				</selftest>

\ JavaScript's hex is a little strange.
\ Example 1: -2 >> 1 is -1 correct, -2 >> 31 is also -1 correct, but -2 >> 32 become -2 !!
\ Example 2: -1 & 0x7fffffff is 0x7fffffff, but -1 & 0xffffffff will be -1 !!
\ That means hex is 32 bits and bit 31 is the sign bit. But not exactly, because 0xfff...(over 32 bits)
\ are still valid numbers. However, my job is just to print hex correctly by using .r and
\ .0r. So I simply use a workaround that prints higher 16 bits and then lower 16 bits respectively.
\ So JavaScript's opinion about hex won't bother me anymore.

code .r         ( num|str n -- ) \ Right adjusted print num|str in n characters (FigTaiwan SamSuanChen)
                var n=pop(); var i=pop();
				if(typeof i == 'number') {
					if(kvm.base == 10){
						i=i.toString(kvm.base);
					}else{
						i = (i >> 16 & 0xffff || "").toString(kvm.base) + (i & 0xffff).toString(kvm.base);
					}
				}
                n=n-i.length;
                if(n>0) do {
					i=" "+i;
					n--;
				} while(n>0);
                print(i);
                end-code

code .0r        ( num|str n -- ) \ Right adjusted print num|str in n characters (FigTaiwan SamSuanChen)
                var n=pop(); var i=pop();
				var minus = "";
				if(typeof i == 'number') {
					if(kvm.base == 10){
						if (i<0) minus = '-';
						i=Math.abs(i).toString(kvm.base);
					}else{
						i = (i >> 16 & 0xffff || "").toString(kvm.base) + (i & 0xffff).toString(kvm.base);
					}
				}
                n=n-i.length - (minus?1:0);
                if(n>0) do {
					i="0"+i;
					n--;
				} while (n>0);
                print(minus+i);
                end-code
				/// Limitation: Negative numbers are printed in a strange way. e.g. "0000-123".
				/// We need to take care of that separately.

				<selftest>
					<text> .r 是 FigTaiwan 爽哥那兒抄來的。 JavaScript 本身就有 number.toString(base) 可以任何 base
					印出數值。base@ base! hex decimal 等只對 .r .0r 有用。輸入時照 JavaScript 的慣例，數字就是十進位，
					0x1234 是十六進位，已經足夠。 .r .0r 很有用, .s 的定義就是靠他們。
					</text> drop

					marker ---

					*** .r .0r can print hex-decimal ...
					selftest-invisible
					decimal  -1 10  .r <js> kvm.screenbuffer.slice(-10)=='        -1'</jsV> \ true
					hex      -1 10  .r <js> kvm.screenbuffer.slice(-10)=='  ffffffff'</jsV> \ true
					decimal  56 10 .0r <js> kvm.screenbuffer.slice(-10)=='0000000056'</jsV> \ true
					hex      56 10 .0r <js> kvm.screenbuffer.slice(-10)=='0000000038'</jsV> \ true
					decimal -78 10 .0r <js> kvm.screenbuffer.slice(-10)=='-000000078'</jsV> \ true
					hex     -78 10 .0r <js> kvm.screenbuffer.slice(-10)=='00ffffffb2'</jsV> \ true
					selftest-visible
					XOR XOR XOR XOR and space
					==>judge [if] <js> ['decimal', 'hex', '.0r'] </jsV> all-pass [then]
					---
				</selftest>

code dropall    stack=[] end-code // ( ... -- ) Clear the data stack.

				<selftest>
					*** dropall clean the data stack ...
					1 2 3 4 5 dropall depth 0= ==>judge drop
				</selftest>

code (ASCII)    push(pop().charCodeAt(0)) end-code // ( str -- ASCII ) Get a character's ASCII code.
code ASCII>char ( ASCII -- 'c' ) \ number to character
				push(String.fromCharCode(pop())) end-code
				/// 65 ASCII>char tib. \ ==> A (string)
: ASCII			( <str> -- ASCII ) \ Get a character's ASCII code.
				BL word (ASCII) compiling if literal then
				; immediate

				<selftest>
					marker ---
					*** ASCII (ASCII) ASCII>char  ...
					char abc (ASCII) 97 = \ true
					98 ASCII>char char b = \ true
					: test ASCII c ; test 99 = \ true
					and and ==>judge [if] <js> ['(ASCII)', 'ASCII>char'] </jsV> all-pass [then]
					---
				</selftest>

: <task>		( <tokens> -- "task" ) \ Run an outer loop.
				char </task> word ; immediate
: </task>		( "task" -- ... ) \ Delimiter of <task>
				compiling if literal js: push(function(){fortheval(pop())}) , 
				else js: fortheval(pop()) then ; immediate

code .s         ( ... -- ... ) \ Dump the data stack.
				var count=stack.length, basewas=kvm.base;
                if(count>0) for(var i=0;i<count;i++){
					if (typeof(stack[i])=="number") {
						push(stack[i]); push(i); fortheval("decimal 7 .r char : . space dup decimal 11 .r space hex 11 .r char h .");
					} else {
						push(stack[i]); push(i); fortheval("decimal 7 .r char : . space .");
					}
					print(" ("+mytypeof(stack[i])+")\n");
                } else print("empty\n");
				kvm.base = basewas;
                end-code

				<selftest>
					marker ---
					*** .s is almost the most used word ...
					selftest-invisible
					32424 -24324 .s
					selftest-visible
					<js> kvm.screenbuffer.indexOf('32424')    !=-1 </jsV> \ true
					<js> kvm.screenbuffer.indexOf('7ea8h')    !=-1 </jsV> \ true
					<js> kvm.screenbuffer.indexOf('-24324')   !=-1 </jsV> \ true
					<js> kvm.screenbuffer.indexOf('ffffa0fch')!=-1 </jsV> \ true
					<js> kvm.screenbuffer.indexOf('2:')       ==-1 </jsV> \ true
					and and and and ==>judge 3 drops
					---
				</selftest>

code (words)    ( "option" "word-list" "pattern" -- word[] ) \ Get an array of words, name/help/comments screened by pattern.
                // var RegEx = new RegExp(nexttoken(),"i");
				var pattern = pop(); // nexttoken('\n|\r'); // if use only '\n' then we get an unexpected ending '\r'.
				var word_list = words[pop()];
				var option = pop();
				var result = [];
                for(var i=1;i<word_list.length;i++) {
					if (!pattern) { result.push(word_list[i]); continue; }
					switch(option){
						case "-n": // -n for matching only name pattern, case insensitive.
							if (word_list[i].name.toLowerCase().indexOf(pattern.toLowerCase()) != -1 ) {
								result.push(word_list[i]);
							}
							break;
						case "-N": // -N for exactly name only, case sensitive.
							if (word_list[i].name==pattern) {
								result.push(word_list[i]);
							}
							break;
						default:
							var flag = 	(word_list[i].name.toLowerCase().indexOf(pattern.toLowerCase()) != -1 ) ||
										(word_list[i].help.toLowerCase().indexOf(pattern.toLowerCase()) != -1 ) ||
										(typeof(word_list[i].comment)!="undefined" && (word_list[i].comment.toLowerCase().indexOf(pattern.toLowerCase()) != -1));
							if (flag) {
								result.push(word_list[i]);
							}
					}
				}
				push(result);
                end-code
				/// option: -n name , -N name

: words			( [<pattern>] -- ) \ List words of name/help/comments screened by pattern.
                "" char forth char \n|\r word (words) <js>
					var word_list = pop();
					var w = "";
					for (var i=0; i<word_list.length; i++) w += word_list[i].name + " ";
					print(w);
				</js> ;
				/// Search the pattern in help and comments also.

: (help)		( "patther" -- ) \ Print help message of screened words
				js> tos().length if
					char forth swap "" -rot (words) <js>
						var word_list = pop();
						for (var i=0; i<word_list.length; i++) {
							print(word_list[i]+"\n");
							if (typeof(word_list[i].comment) != "undefined") print(" "+word_list[i].comment+"\n");
						}
					</js>
				else
					<text>
						Enter          : Focus to the input box
						help <pattern> : Print help message of matched words
						see <word>     : See details of the word
						jsc            : JavaScript console
					</text> <js> pop().replace(/^[ \t]*/gm,'  ')</jsV> . cr
				then ;
				/// Original version
				/// Pattern matches name, help and comments.

: help			( [<pattern>] -- ) \ Print help message of screened words
                char \n|\r word (help) ;
				/// Original version
				/// Pattern matches name, help and comments.

				<selftest>

					<text>
					本來 words help 都接受 RegEx 的，可是不好用。現已改回普通 non RegEx pattern. 只動
					(words) 就可以來回修改成 RegEx/non-RegEx.
					</text> drop

					marker ---
					*** help words (words) ...
					: test ; // testing help words and (words) 32974974
					/// 9247329474 comment
					selftest-invisible
					help test
					<js> kvm.screenbuffer.indexOf('32974974') !=-1 </jsV> \ true
					<js> kvm.screenbuffer.indexOf('9247329474') !=-1 </jsV> \ true
					words 9247329474
					<js> kvm.screenbuffer.indexOf('test') !=-1 </jsV> \ true
					words test
					selftest-visible
					<js> kvm.screenbuffer.indexOf('<selftest>') !=-1 </jsV> \ true
					<js> kvm.screenbuffer.indexOf('***') !=-1 </jsV> \ true
					and and and and ==>judge [if] <js> ['(words)', 'words'] </jsV> all-pass [then]
					---
				</selftest>

code bye        ( ERRORLEVEL -- ) \ Exit to shell with TOS as the ERRORLEVEL.
                // 這些都無效，最後靠 WMI 達成傳回 errorlevel // var errorlevel = pop(); window.errorlevel = typeof(errorlevel)=='number' ? errorlevel : 0; 
                kvm.bye();
                end-code

code readTextFile ( "pathname" -- string ) \ Return a string, "" if failed
				try {
					var data = kvm.readTextFile(pop()); 
				} catch (err) {
					data = "";
				}
				push(data);
				end-code

: readTextFileAuto ( "pathname" -- string ) \ Search and read, panic if failed.
				js> kvm.path.slice(0) \ this is the way javascript copy array by value
				over readTextFile js> tos()!="" if nip nip exit then drop
				js> tos().length for aft ( -- fname [path] )
					js> tos().pop()+'/'+tos(1) 
					readTextFile js> tos()!=""
					if ( -- fname [path] file )
						nip nip r> drop exit \ for..next loop 裡面不能光 exit !!!
					then drop ( -- fname [path] )
				then next ( -- fname [path] )
				drop "" swap <js> panic("Error! File " + pop() + " not found!\n",true) </js> ;

code writeTextFile ( string "pathname" -- ) \ Write string to file. Panic if failed.
				kvm.writeTextFile(pop(),pop())
				end-code

\ code tib.append	( "string" -- ) \ Append the "string" to TIB
\ 				tib += " " + (pop()||""); end-code
\ 				/// KVM suspend-resume doesn't allow multiple levels of fortheval() so
\ 				/// we need tib.append or tib.insert.

code tib.append	( "string" -- ) \ Append the "string" to TIB
				tib = tib.slice(ntib); ntib = 0;
				tib += " " + (pop()||""); end-code
				/// KVM suspend-resume doesn't allow multiple levels of fortheval() so
				/// we need tib.append or tib.insert.

				<comment>
					靠！ tib.append 沒辦法測呀！到了 terminal prompt 手動這樣測，
					OK 111 s" 12345" tib.append 222
					OK .s
						0:         111          6fh (number)
						1:         222          deh (number)
						2:       12345        3039h (number) <=== appended to the ending
				</comment>

\ code tib.insert	( "string" -- ) \ Insert the "string" into TIB
\ 				var before = tib.slice(0,ntib), after = tib.slice(ntib);
\ 				tib = before + " " + (pop()||"") + " " + after; end-code
\ 				/// KVM suspend-resume doesn't allow multiple levels of fortheval() so
\ 				/// we need tib.append or tib.insert.

code tib.insert	( "string" -- ) \ Insert the "string" into TIB
				tib = tib.slice(ntib); ntib = 0;
				tib = (pop()||"") + " " + tib; end-code
				/// KVM suspend-resume doesn't allow multiple levels of fortheval() so
				/// we need tib.append or tib.insert.

: sinclude.js	( "pathname" -- ) \ Include JavaScript source file
				readTextFile js: eval(pop()) ;

: include.js	( <pathname> -- ) \ Include JavaScript source file
				BL word sinclude.js ;

: sinclude		( "pathname" -- ... ) \ Lodad the given forth source file.
				readTextFileAuto ( -- file )
				js> tos().indexOf("source-code-header")!=-1 if \ 有 selftest 的正常 .f 檔
					<text> 
						\ 跟 source-code-header 成對的尾部
						<selftest>
						js> tick('<selftest>').masterMarker tib.insert
						</selftest>
						js> tick('<selftest>').enabled [if] js> tick('<selftest>').buffer tib.insert [then]
						js: tick('<selftest>').buffer="" \ recycle the memory
						\ --EOF--
					</text>
					swap  ( -- code file )
					<js> // 把 \ --EOF-- 之後先切除再加回，為往後的 source code header, selftest 等準備。
						var ss = pop();
						ss = (ss+'x').slice(0,ss.search(/\\\s*--EOF--/)); // 一開始多加一個 'x' 讓 search 結果 -1 時吃掉。
						ss += pop(); // Now ss becomes the TOS
					</jsV>
				then
				js> '\n'+pop()+'\n' ( 避免最後是 \ comment 時吃到後面來 ) tib.insert ;

: include       ( <filename> -- ... ) \ Load the source file if it's not included yet.
				BL word sinclude ; interpret-only

: source-code-header
				( -- ) \ The source-code-file.f header macro
				<text>
					?skip2 --EOF-- \ skip it if already included
					dup .( Including ) . cr char -- over over + +
					js: tick('<selftest>').masterMarker=tos()+"selftest--";
					also forth definitions (marker) (vocabulary)
					last execute definitions
					<selftest>
						js> tick('<selftest>').masterMarker (marker)
						include kernel/selftest.f
					</selftest>
				</text> tib.insert ;
				/// skip including if the module has been included.
				/// setup the self-test module
				/// initiate vocabulary for the including module

code memberCount ( obj -- count ) \ Get hash table's length or an object's member count.
				push(g.memberCount(pop()));
				end-code

code isSameArray ( a1 a2 -- T|F ) \ Compare two arrays.
				push(g.isSameArray(pop(), pop()));
				end-code

code (?)        ( a -- ) \ print value of the variable consider ret and exit
				var x = dictionary[pop()];
				switch(x){
					case null: print('RET');break;
					case "": print('EXIT');break;
					default: print(x);
				}; end-code

: (dump)		( addr -- ) \ dump one cell of dictionary
				decimal dup 5 .0r s" : " . dup (?) s"  (" . js> mytypeof(dictionary[pop()]) . s" )" . cr ;
: dump          ( addr length -- addr' ) \ dump dictionary
                for ( addr ) dup (dump) 1+ next ;
: d        		( <addr> -- ) \ dump dictionary
                [ last literal ]
                BL word  					\ (me str)
                count 0= 					\ (me str undef?) No start address?
                if       					\ (me str)
                    drop 					\ drop the undefined  (me)
					js> tos().lastaddress   \ (me addr)
                else  						\ (me str)
                    js> parseInt(pop())		\ (me addr)
                then ( me addr )
				20 dump 						\ (me addr')
				js: pop(1).lastaddress=pop()
                ;

code (see)      ( thing -- ) \ See into the given word, object, array, ... anything.
                var w=pop();
				var basewas = kvm.base; kvm.base = 10;
                if (!(w instanceof Word)) {
                    g.see(w);  // none forth word objects. 意外的好處是不必有 "unkown word" 這種無聊的錯誤訊息。
                }else{
                    for(var i in w){
                        if (typeof(w[i])=="function") continue;
                        if (i=="comment") continue;
                        push(i); fortheval("16 .r s'  : ' .");
                        print(w[i]+" ("+mytypeof(w[i])+")\n");
                    }
                    if (w.type.indexOf("colon")!=-1){
                        var i = w.cfa;
                        print("\n-------- Definition in dictionary --------\n");
                        do {
							push(i); execute("(dump)");
                        } while (dictionary[i++] != RET);
                        print("---------- End of the definition -----------\n");
                    } else {
                        for(var i in w){
                            if (typeof(w[i])!="function") continue;
                            // if (i=="selfTest") continue;
                            push(i); fortheval("16 .r s'  :\n' .");
                            print(w[i]+"\n");
                        }
                    }
                    if (w.comment != undefined) print("\ncomment:\n"+w.comment+"\n");
                }
				kvm.base = basewas;
                end-code
: see           ' (see) ; // ( <name> -- ) See definition of the word

				<selftest>
					marker ---
					*** see (see) ...
					: test ; // test.test.test
					selftest-invisible
					see test
					selftest-visible
					<js> kvm.screenbuffer.indexOf('test.test.test') !=-1 </jsV> \ true
					<js> kvm.screenbuffer.indexOf('cfa') !=-1 </jsV> \ true
					<js> kvm.screenbuffer.indexOf('colon') !=-1 </jsV> \ true
					and and ==>judge [if] <js> ['(see)'] </jsV> all-pass [then]
					---
				</selftest>

code notpass	( -- ) \ List words their sleftest flag are not 'pass'.
				for (var j in words) { // all word-lists
					for (var i in words[j]) {  // all words in a word-list
						if(i!=0 && words[j][i].selftest != 'pass') print(words[j][i].name+" ");
					}
				}
				end-code

				<selftest>
					*** d dump ...
					selftest-invisible
					d 0
					selftest-visible
					<js> kvm.screenbuffer.indexOf('00000: 0 (number)') !=-1 </jsV> \ true
					==>judge [if] <js> ['dump', 'd'] </jsV> all-pass [then]
				</selftest>

\ -------------- Forth Debug Console -------------------------------------------------

js> inner constant fastInner // ( -- inner ) Original inner() without breakpoint support
code bp			( <address> -- ) \ Set breakpoint in a colon word. See also 'db' command.
				bp = parseInt(nexttoken()); inner = g.debugInner; end-code
				/// work with 'jsc' debug console, jsc is application dependent.
code db			( -- ) \ Disable breakpoint, inner=fastInner. See also 'bp' command.
				inner = g.fastInner end-code
				/// work with 'jsc' debug console, jsc is application dependent.
				
: (*debug*) 	( msg -- resume ) \ Suspend to command prompt, execute resume() to quit debugging.
				<js>
					var tibwas=tib, ntibwas=ntib, ipwas=ip, promptwas=kvm.prompt;
					kvm.prompt = pop().toString();
					push(resume); // The clue for resume
					tib = ""; ntib = ip = 0; // ip = 0 reserve rstack, suspend the forth VM 
					function resume(){tib=tibwas; ntib=ntibwas; kvm.prompt=promptwas;outer(ipwas);}
				</js> ;
				/// resume() 線索由 data stack 傳回，故可以多重 debug。但有何用途？
				
: *debug*		( <prompt> -- resume ) \ Forth debug console. Execute the resume() to quit debugging.
				BL word compiling if literal compile (*debug*) 
				else (*debug*) then ; immediate
				/// resume() 線索由 data stack 傳回，故可以多重 debug。但有何用途？

\ ----------------- play ground -------------------------------------

\ ----------------- Self Test -------------------------------------

<selftest>
	<js> ['accept', 'refill', 'wut', '==>judge', 'all-pass', '***',
		  '~~selftest~~', '.((', 'sleep'
	] </jsV> all-pass
	~~selftest~~ \ forget self-test temporary words
</selftest>

\ jeforth.f kernel code is now common for different application. I/O may not ready enough to read 
\ selftest.f at this moment, so the below code has been moved to quit.f of each applications.
	\ Do the jeforth.f self-test only when there's no command line
	\	js> kvm.argv.length 1 > \ Do we have jobs from command line?
	\	[if] \ We have jobs from command line to do. Disable self-test.
	\		js: tick('<selftest>').enabled=false
	\	[else] \ We don't have jobs from command line to do. So we do the self-test.
	\		js> tick('<selftest>').enabled=true;tick('<selftest>').buffer tib.insert
	\	[then] js: tick('<selftest>').buffer="" \ recycle the memory
