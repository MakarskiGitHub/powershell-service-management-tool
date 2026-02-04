# powershell-service-management-tool

Interactive PowerShell script for managing Windows services across multiple servers and environments.

The script allows administrators to **start, stop, or restart services** in a controlled and safe way, based on:
- selected regions
- selected environments
- selected action

## 🖥️ Supported Environments

- Windows Server
- PowerShell 5.1+
- WinRM enabled on target servers
- Required permissions to manage services remotely

## 🕹️ How It Works

1. User selects:
   - Regions
   - Environments
   - Action (START / STOP / RESTART)
2. Script validates all inputs
3. Script builds a list of:
   - target servers
   - services to manage
4. User confirms execution
5. Script executes the action remotely on selected servers

If no services are selected or invalid input is provided, the script **will not execute**.

## ⚙️ Configuration 

Editable variables are located **at the top** of the script!
