@echo off
rem Licensed under the Apache License, Version 2.0 (the "License");
rem you may not use this file except in compliance with the License.
rem You may obtain a copy of the License at
rem
rem      https://www.apache.org/licenses/LICENSE-2.0
rem
rem Unless required by applicable law or agreed to in writing, software
rem distributed under the License is distributed on an "AS IS" BASIS,
rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem See the License for the specific language governing permissions and
rem limitations under the License.

SETLOCAL
SET PWD=%~dp0

SET OUTPUT=output.txt
SET CLASSPATH=%PWD%\formatter.jar
call %PWD%\check_env_windows.bat

call %PWD%\..\data\setup_%LOCALE%.bat
if %LOCALE% == ja ( SET CITY=Tokyo )
if %LOCALE% == ko ( SET CITY=Seoul )
if %LOCALE% == zh-cn ( SET CITY=Shanghai )
if %LOCALE% == zh-tw ( SET CITY=Taipei )

echo "invoking FormatterTest2" > %OUTPUT%
%JAVA_BIN%\java -Duser.timezone=Asia/%CITY% FormatterTest2 abc%TEST_STRING% >> %OUTPUT%

fc %PWD%\expected_windows_%LOCALE%.txt %OUTPUT% > fc.out 2>&1
exit %errorlevel%
