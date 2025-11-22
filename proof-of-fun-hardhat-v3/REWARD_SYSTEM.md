# Sistema de Recompensas Proof of Fun

## 📋 Resumen

Sistema completo de votación anónima con tokens de recompensa **no transferibles (Soulbound)** para eventos. Los usuarios ganan tokens por asistir y completar encuestas, que pueden canjear por merchandise sin valor económico real.

## 🎯 Contratos

### 1. **EventRewardToken.sol**
Token ERC20 **no transferible** (Soulbound) que se crea para cada evento.

**Características:**
- ✅ No se puede transferir entre usuarios (bloqueado en `_update`)
- ✅ Solo se puede mintear y quemar
- ✅ Nombre único por evento: "Proof of Fun - {EventName}"
- ✅ Dos tipos de recompensas configurables:
  - `attendanceReward`: Tokens por asistir al evento
  - `surveyReward`: Tokens por completar la encuesta

**Funciones principales:**
```solidity
rewardAttendance(address user)      // Otorga tokens por asistencia
rewardSurvey(address user)          // Otorga tokens por completar encuesta
burnFrom(address user, uint256 amount, string reason) // Quema tokens al canjear
getUserProgress(address user)       // Obtiene progreso del usuario
```

### 2. **EventManager.sol** (Modificado)
Gestiona el ciclo de vida de los eventos y crea tokens de recompensa.

**Nuevas funcionalidades:**
- ✅ Crea `EventRewardToken` automáticamente al crear evento
- ✅ `markAttendance()` otorga tokens automáticamente (simula escaneo QR)
- ✅ `batchMarkAttendance()` para procesar múltiples asistentes
- ✅ Cada evento tiene su propio token de recompensa

**Parámetros adicionales en createEvent:**
```solidity
uint256 _attendanceReward  // Ej: 100 tokens por asistir
uint256 _surveyReward      // Ej: 200 tokens por completar encuesta
```

### 3. **ProofOfFun.sol** (Modificado)
Sistema de votación anónima que otorga tokens al completar encuestas.

**Nuevas funcionalidades:**
- ✅ Integración con `EventManager`
- ✅ Detecta automáticamente cuando un usuario completa todas las categorías
- ✅ Otorga `surveyReward` al completar la encuesta completa
- ✅ Solo otorga una vez por usuario por evento

**Función modificada:**
```solidity
batchVote(...) // Ahora otorga tokens al completar todas las categorías
```

### 4. **MerchRedemption.sol** (Nuevo)
Sistema de canje de tokens por merchandise.

**Características:**
- ✅ Gestión de inventario de merchandise
- ✅ Configuración de precios en tokens
- ✅ Límite por usuario por artículo
- ✅ Tallas para ropa
- ✅ Categorías (clothing, accessories, tech, other)
- ✅ Estados de canje: Pending → Confirmed → Shipped → Delivered
- ✅ Sistema de tracking
- ✅ Cancelación con devolución de stock

**Funciones principales:**
```solidity
createMerchItem(...)               // Crear artículo de merch
redeemMerch(itemId, quantity, size, token) // Canjear tokens
updateRedemptionStatus(...)        // Actualizar estado del canje
cancelRedemption(...)              // Cancelar canje
```

### 5. **AnonymousVoteToken.sol**
Token ERC721 no transferible que representa el recibo de voto.

## 🔄 Flujo del Sistema

### 1️⃣ Creación del Evento
```
Organizador → EventManager.createEvent()
  ├─ Crea evento con attendanceReward y surveyReward
  ├─ Crea automáticamente EventRewardToken para el evento
  └─ Token configurado con recompensas específicas
```

### 2️⃣ Asistencia al Evento (Escaneo QR simulado)
```
Usuario llega al evento
  ↓
Organizador → EventManager.markAttendance(eventId, userAddress)
  ├─ Marca asistencia en blockchain
  ├─ Otorga automáticamente attendanceReward tokens
  └─ Emite evento AttendanceRewarded
```

### 3️⃣ Completar Encuesta
```
Usuario vota en todas las categorías
  ↓
Usuario → ProofOfFun.batchVote(eventId, categories, ratings, salt)
  ├─ Registra votos anónimamente
  ├─ Detecta si completó todas las categorías
  ├─ Otorga automáticamente surveyReward tokens
  └─ Usuario ahora tiene: attendanceReward + surveyReward tokens
```

### 4️⃣ Canje por Merchandise
```
Usuario ve catálogo de merch
  ↓
Usuario → MerchRedemption.redeemMerch(itemId, quantity, size, tokenAddress)
  ├─ Verifica balance de tokens
  ├─ Quema tokens (burnFrom)
  ├─ Crea orden de canje (Redemption)
  ├─ Descuenta stock
  └─ Estado: Pending
  
Organizador → updateRedemptionStatus(redemptionId, Confirmed, trackingInfo)
  └─ Confirmed → Shipped → Delivered
```

## 📊 Ejemplo Práctico

### Configuración del Evento
```solidity
EventManager.createEvent(
  "ETH Global 2025",
  "Hackathon de blockchain",
  "Buenos Aires",
  "https://...",
  startTime,
  endTime,
  votingStart,
  votingEnd,
  500,        // maxParticipants
  true,       // requiresRegistration
  100,        // attendanceReward = 100 tokens
  200         // surveyReward = 200 tokens
)
```

### Usuario Juan
1. **Asiste al evento**: Recibe 100 tokens
2. **Completa encuesta**: Recibe 200 tokens adicionales
3. **Total**: 300 tokens

### Catálogo de Merch
```
- Polera oficial: 150 tokens
- Gorra: 100 tokens
- Stickers pack: 50 tokens
- Tote bag: 120 tokens
```

### Juan canjea
- 1 Polera (150 tokens) → Le quedan 150 tokens
- 1 Gorra (100 tokens) → Le quedan 50 tokens
- 1 Stickers pack (50 tokens) → 0 tokens restantes

## 🔐 Seguridad

### Tokens No Transferibles
```solidity
function _update(address from, address to, uint256 value) internal override {
    // Solo permite mint (from == 0) y burn (to == 0)
    // Bloquea todas las transferencias normales
    if (from != address(0) && to != address(0)) {
        revert("EventRewardToken: tokens are non-transferable (soulbound)");
    }
    super._update(from, to, value);
}
```

### Protecciones
- ✅ ReentrancyGuard en todas las funciones críticas
- ✅ Pausable para emergencias
- ✅ AccessControl para roles
- ✅ Una sola recompensa por asistencia por usuario
- ✅ Una sola recompensa por encuesta por usuario
- ✅ Límites de canje por artículo por usuario

## 🎫 Roles

### EventManager
- `ORGANIZER_ROLE`: Crear eventos, marcar asistencias
- `ADMIN_ROLE`: Administración general

### EventRewardToken
- `MINTER_ROLE`: Otorgar tokens (EventManager y ProofOfFun)
- `BURNER_ROLE`: Quemar tokens (MerchRedemption)

### MerchRedemption
- `ORGANIZER_ROLE`: Crear/editar merchandise
- `FULFILLER_ROLE`: Actualizar estados de canjes

## 📡 Endpoints para Backend (Sugeridos)

### 1. **POST /api/events/{eventId}/scan-attendance**
```json
{
  "userAddress": "0x123...",
  "qrCode": "QR_CODE_DATA"
}
```
→ Llama a `EventManager.markAttendance()`

### 2. **POST /api/events/{eventId}/vote**
```json
{
  "categoryIds": [0, 1, 2, 3, 4, 5],
  "ratings": [5, 4, 5, 5, 4, 5],
  "salt": "0xabc..."
}
```
→ Llama a `ProofOfFun.batchVote()`

### 3. **GET /api/merch/catalog**
```json
{
  "items": [
    {
      "id": 0,
      "name": "Polera ETH Global",
      "price": 150,
      "stock": 50,
      "sizes": ["S", "M", "L", "XL"]
    }
  ]
}
```

### 4. **POST /api/merch/redeem**
```json
{
  "itemId": 0,
  "quantity": 1,
  "size": "M",
  "tokenAddress": "0x456..."
}
```
→ Llama a `MerchRedemption.redeemMerch()`

### 5. **GET /api/users/{address}/rewards**
```json
{
  "events": [
    {
      "eventId": 0,
      "attendanceClaimed": true,
      "surveyClaimed": true,
      "balance": 300,
      "tokenAddress": "0x789..."
    }
  ]
}
```

## 🚀 Deployment

```bash
# Compilar contratos
npm run compile

# Desplegar a Base Sepolia
npx hardhat ignition deploy ignition/modules/ProofOfFunComplete.ts --network baseSepolia

# Verificar contratos
npx hardhat verify --network baseSepolia <ADDRESS>
```

## 📝 Notas Importantes

1. **No Valor Económico**: Los tokens son soulbound y solo sirven para canjear merch del evento
2. **Un Token por Evento**: Cada evento tiene su propio EventRewardToken independiente
3. **No Mercados Secundarios**: Al ser no transferibles, no pueden venderse en DEXs
4. **Retención de Usuarios**: Los usuarios deben quedarse hasta el final para completar la encuesta y obtener todas las recompensas
5. **QR Simulado**: Por ahora el escaneo QR es off-chain (backend), pero la asistencia se registra on-chain

## 🔧 Configuración Recomendada

### Tokens por Evento
```
- Asistencia: 100 tokens (33% del total)
- Encuesta completa: 200 tokens (67% del total)
- Total posible: 300 tokens por usuario
```

### Precios Sugeridos de Merch
```
- Items básicos: 50-100 tokens (stickers, badges)
- Items medianos: 100-200 tokens (gorras, tote bags)
- Items premium: 200-300 tokens (poleras, hoodies)
```

Esto asegura que los usuarios deben completar ambas acciones para obtener items premium.
