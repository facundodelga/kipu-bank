# KipuBank

KipuBank es un contrato inteligente en Solidity que implementa una bóveda bancaria simple para depósitos y retiros de ETH, siguiendo buenas prácticas de seguridad y documentación.

## 📌 Características

- Los usuarios pueden **depositar ETH** en su bóveda personal.
- Los usuarios pueden **retirar ETH** respetando un límite fijo por transacción (`WITHDRAW_LIMIT`).
- Existe un **límite global de depósitos** en el banco (`BANK_CAP`).
- Cada interacción genera **eventos** (`Deposit`, `Withdrawal`).
- Se lleva registro del número de depósitos y retiros.
- Buenas prácticas:
  - Errores personalizados en lugar de `require` con string.
  - Patrón *checks-effects-interactions*.
  - Uso de modificadores para validaciones.
  - Transferencias nativas seguras.
  - Comentarios **NatSpec** en todas las funciones y variables.

## 🚀 Instrucciones de despliegue

1. Abrir [Remix Ethereum IDE](https://remix.ethereum.org/).  
2. Crear un archivo en `/contracts/KipuBank.sol`.  
3. Pegar el código del contrato.  
4. Compilar con Solidity **v0.8.30 o superior**.  
5. En **Deploy & Run Transactions**:  
   - Seleccionar **Injected Provider (MetaMask)**.  
   - Elegir una testnet (ej: Sepolia o Goerli).  
   - Definir el parámetro `_withdrawLimit` (ejemplo: `1000000000000000000` para 1 ETH).  
   - Click en **Deploy**.  

## 🤓 Interactuar con el contrato

### Depositar ETH
1. Llamar a `deposit()`.  
2. Indicar un valor en el campo **Value (ETH)**.  
3. Confirmar la transacción en MetaMask.  

### Retirar ETH
1. Llamar a `withdraw(amount)`.  
2. Ejemplo: `withdraw(500000000000000000)` → retira 0.5 ETH.  

### Consultar balances
- `getBalance(userAddress)` → retorna el balance del usuario.  
- `getBankBalance()` → retorna el total de ETH en el contrato.  

## 🔎 Datos del Contrato
- Direccion del contrato [0xABfFeD220A50bB23aCf4EE1C1D5E0D8A161c974b]
- Etherscan: https://sepolia.etherscan.io/address/0xABfFeD220A50bB23aCf4EE1C1D5E0D8A161c974b
- Argumentos de entrada utilizados :
   - _withdrawLimit : 1 ETH
   - _bankCap : 10 ETH
