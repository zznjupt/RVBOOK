
### remote: Support for password authentication was removed
    
    [参考链接](https://stackoverflow.com/questions/68775869/support-for-password-authentication-was-removed-please-use-a-personal-access-to)
    
    From your GitHub account, go to **Settings** => **Developer Settings** => **Personal Access Token**=> **Generate New Token** (Give your password) => **Fillup the form**=> click **Generate token** => **Copy the generated Token**, it will be something like `ghp_sFhFsSHhTzMDreGRLjmks4Tzuzgthdvfsrta`
    
    `git clone https://<tokenhere>@github.com/<user>/<repo>.git`