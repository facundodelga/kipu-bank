// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title KipuBank
 * @author -
 * @notice Simple vault-like bank donde usuarios depositan ETH en bóvedas personales.
 * @dev Implementa buenas prácticas: errores personalizados, checks-effects-interactions,
 *      transferencias nativas seguras, modificadores y NatSpec.
 * @custom:dev-run-script scripts/deploy_with_ethers.ts
 */
contract KipuBank {
    /* ========== CONSTANTS & IMMUTABLES ========== */

    /// @notice Límite por retiro por transacción (en wei). Inmutable establecido en despliegue.
    uint256 public immutable WITHDRAW_LIMIT;

    /// @notice Límite global del banco para fondos depositados simultáneamente (en wei). Inmutable.
    uint256 public immutable BANK_CAP;

    /// @notice Versión del contrato (constante).
    string public constant VERSION = "KipuBank v1";

    /* ========== STATE ========== */

    /// @notice Saldo por usuario (bóveda personal).
    mapping(address => uint256) private _balances;

    /// @notice Suma total de fondos almacenados actualmente en el banco.
    uint256 private _totalVaultBalance;

    /// @notice Cantidad de depósitos exitosos realizados al contrato.
    uint256 public depositCount;

    /// @notice Cantidad de retiros exitosos realizados desde el contrato.
    uint256 public withdrawCount;

    /* ========== EVENTS ========== */

    /// @notice Emitido cuando un usuario deposita ETH.
    /// @param user Dirección del depositante.
    /// @param amount Monto depositado en wei.
    /// @param newBalance Nuevo saldo del usuario después del depósito.
    event Deposit(address indexed user, uint256 amount, uint256 newBalance);

    /// @notice Emitido cuando un usuario retira ETH.
    /// @param user Dirección del retirante.
    /// @param amount Monto retirado en wei.
    /// @param newBalance Nuevo saldo del usuario después del retiro.
    event Withdrawal(address indexed user, uint256 amount, uint256 newBalance);

    /* ========== ERRORS ========== */

    /// @notice Depósito de valor cero no permitido.
    error ErrZeroDeposit();

    /// @notice Límite global del banco excedido al intentar depositar.
    /// @param attempted Monto que intentó ingresarse.
    /// @param available Monto disponible hasta alcanzar el bankCap.
    error ErrBankCapExceeded(uint256 attempted, uint256 available);

    /// @notice Saldo insuficiente para retirar.
    /// @param available Saldo disponible del usuario.
    /// @param requested Monto solicitado para retirar.
    error ErrInsufficientBalance(uint256 available, uint256 requested);

    /// @notice El retiro excede el límite por transacción.
    /// @param limit Límite por transacción establecido.
    /// @param requested Monto solicitado.
    error ErrWithdrawLimitExceeded(uint256 limit, uint256 requested);

    /// @notice Transferencia nativa falló.
    error ErrNativeTransferFailed();

    /* ========== MODIFIERS ========== */

    /// @notice Valida que un monto sea mayor a cero.
    /// @param amount Monto a validar.
    modifier positive(uint256 amount) {
        if (amount == 0) revert ErrZeroDeposit();
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Inicializa KipuBank.
     * @param withdrawLimit Límite por retiro por transacción en wei.
     * @param bankCap Límite global del banco en wei.
     */
    constructor(uint256 withdrawLimit, uint256 bankCap) {
        // controles simples: límites no nulos
        require(withdrawLimit > 0, "withdrawLimit must be > 0");
        require(bankCap > 0, "bankCap must be > 0");

        WITHDRAW_LIMIT = withdrawLimit;
        BANK_CAP = bankCap;
    }

    /* ========== EXTERNAL & PUBLIC FUNCTIONS ========== */

    /**
     * @notice Deposita ETH en la bóveda del remitente.
     * @dev Sigue checks-effects-interactions. Revert con errores personalizados.
     * @custom:reverts ErrZeroDeposit si msg.value == 0.
     * @custom:reverts ErrBankCapExceeded si el depósito excede BANK_CAP.
     */
    function deposit() external payable positive(msg.value) {
        uint256 amount = msg.value;

        // chequeos
        uint256 available = BANK_CAP - _totalVaultBalance;
        if (amount > available) revert ErrBankCapExceeded(amount, available);

        // efectos
        _balances[msg.sender] += amount;
        _totalVaultBalance += amount;

        _incrementDepositCount();

        // interacción (solo eventos, no llamadas externas a terceros)
        emit Deposit(msg.sender, amount, _balances[msg.sender]);
    }

    /**
     * @notice Retira hasta `amount` wei desde la bóveda del remitente.
     * @dev Sigue checks-effects-interactions. Actualiza estado antes de enviar ETH.
     * @param amount Monto a retirar en wei.
     * @custom:reverts ErrZeroDeposit si amount == 0.
     * @custom:reverts ErrWithdrawLimitExceeded si amount > WITHDRAW_LIMIT.
     * @custom:reverts ErrInsufficientBalance si no hay saldo suficiente.
     * @custom:reverts ErrNativeTransferFailed si la transferencia falla.
     */
    function withdraw(uint256 amount) external positive(amount) {
        if (amount > WITHDRAW_LIMIT) revert ErrWithdrawLimitExceeded(WITHDRAW_LIMIT, amount);

        uint256 userBalance = _balances[msg.sender];
        if (userBalance < amount) revert ErrInsufficientBalance(userBalance, amount);

        // effects: reducir saldo y total antes de interacción externa.
        _balances[msg.sender] = userBalance - amount;
        _totalVaultBalance -= amount;

        _incrementWithdrawCount();

        // interaction: transferencia segura.
        _safeTransfer(payable(msg.sender), amount);

        emit Withdrawal(msg.sender, amount, _balances[msg.sender]);
    }

    /**
     * @notice Obtiene el saldo de la bóveda de `user`.
     * @param user Dirección a consultar.
     * @return balance Saldo en wei.
     */
    function getVaultBalance(address user) external view returns (uint256 balance) {
        return _balances[user];
    }

    /**
     * @notice Obtiene el balance total retenido por el banco (suma de todas las bóvedas).
     * @return totalBalance Balance total en wei.
     */
    function getBankTotalBalance() external view returns (uint256 totalBalance) {
        return _totalVaultBalance;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @dev Incrementa el contador de depósitos.
    function _incrementDepositCount() private {
        depositCount += 1;
    }

    /// @dev Incrementa el contador de retiros.
    function _incrementWithdrawCount() private {
        withdrawCount += 1;
    }

    /**
     * @dev Transferencia nativa segura usando call. Revert con error personalizado si falla.
     * @param to Destino payable.
     * @param amount Monto en wei.
     */
    function _safeTransfer(address payable to, uint256 amount) private {
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert ErrNativeTransferFailed();
    }

    /* ========== RECEIVE / FALLBACK ========== */

    /**
     * @notice Rechaza envíos directos a menos que se llame `deposit()`.
     * @dev Esto fuerza a usar la función deposit explicita para garantizar checks y eventos.
     */
    receive() external payable {
        revert ErrZeroDeposit(); // fuerza al usuario a usar deposit() y evita depósitos accidentales sin checks.
    }

    fallback() external payable {
        revert ErrZeroDeposit();
    }
}
