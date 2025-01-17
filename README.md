# 自动化脚本

我已经对Windows电脑的环境配置又爱又恨，他好烦啊，每次的环境配置都不一样，让我好痛苦，我打算自己写一个可以很好控制环境配置的自动化脚本好点，顺便学学脚本

# 主要内容

## 检测目前环境

1. 可以检查目前电脑上是否有以下语言的环境
    1. C/C++
    2. Golang
    3. Java
    4. Python
    5. …
2. 可以在自定义的盘符里安装一个新的文件夹来放置envs
    
    
3. 可以在不同的环境中下载最新的版本来安装
    
    使用了 `Invoke-WebRequest` 来下载压缩包。你可以使用 PowerShell 中的 `Expand-Archive` 来自动解压这些包。
   
    自动化安装压缩包并配置环境变量
    
5. 最后可以检验安装是否成功

# 在Window上的脚本
使用[PowerShell](https://learn.microsoft.com/en-us/powershell/)来做这个自动化
