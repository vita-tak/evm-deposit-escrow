# Deployment Information

## Smart Contract

**CONTRACT ADDRESS:** `0x7973D492096Bc16F4e40bCB842d5f259223741D7`  
**NETWORK:** Polygon Amoy (Chain ID: 80002)  
**BLOCK:** 30193429  
**TX HASH:** `0x59a160b075ed2a7b4bc2b6ed6961fb91f63455bfdc65372d669302f5fd33d01e`  
**VERIFIED:** Yes (Sourcify)

**Links:**

- [View Contract](https://amoy.polygonscan.com/address/0x7973D492096Bc16F4e40bCB842d5f259223741D7)
- [View Deployment TX](https://amoy.polygonscan.com/tx/0x59a160b075ed2a7b4bc2b6ed6961fb91f63455bfdc65372d669302f5fd33d01e)

---

## Chainlink Automation

**Upkeep ID:** `4472225491410256762188850194717114897121073518523335872510088321560504978877`  
**Forwarder Address:** `0x3EC499f665C65330096Dc4b67652F5e556DAF02A`  
**Status:** Active  
**Check Interval:** ~10 minutes

**Set Forwarder TX:** `0x13d26aa9f5c28918cb3f10a2765299b23e9dda868059e050c548b209ffc6e2dd`

**Links:**

- [View Chainlink Dashboard](https://automation.chain.link/polygon-amoy/4472225491410256762188850194717114897121073518523335872510088321560504978877)
- [View setForwarder TX](https://amoy.polygonscan.com/tx/0x13d26aa9f5c28918cb3f10a2765299b23e9dda868059e050c548b209ffc6e2dd)

## 🧪 Quick Test Commands

### Read Contract State

```bash
# Check owner
cast call 0x7973D492096Bc16F4e40bCB842d5f259223741D7 \
  "owner()(address)" \
  --rpc-url https://rpc-amoy.polygon.technology/

# Check platform fee
cast call 0x7973D492096Bc16F4e40bCB842d5f259223741D7 \
  "platformFee()(uint256)" \
  --rpc-url https://rpc-amoy.polygon.technology/

# Check forwarder
cast call 0x7973D492096Bc16F4e40bCB842d5f259223741D7 \
  "forwarder()(address)" \
  --rpc-url https://rpc-amoy.polygon.technology/

# Check if automation is needed
cast call 0x7973D492096Bc16F4e40bCB842d5f259223741D7 \
  "checkUpkeep(bytes)(bool,bytes)" \
  0x \
  --rpc-url https://rpc-amoy.polygon.technology/
```

### Get Contract Details

```bash
# Get next contract ID
cast call 0x7973D492096Bc16F4e40bCB842d5f259223741D7 \
  "nextContractId()(uint256)" \
  --rpc-url https://rpc-amoy.polygon.technology/
```
