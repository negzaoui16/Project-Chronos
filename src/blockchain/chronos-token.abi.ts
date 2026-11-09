/**
 * Minimal ChronosToken ABI used by the backend.
 *
 * These signatures come from the Hardhat artifact generated at:
 * artifacts/contracts/ChronosToken.sol/ChronosToken.json
 *
 * Keeping only the required functions reduces coupling while preserving the
 * exact on-chain interface.
 */
export const CHRONOS_TOKEN_ABI = [
  'function mintStudent(address student)',
  'function balanceOf(address account) view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function hasReceivedInitialTokens(address account) view returns (bool)',
  'function hasMinterRole(address account) view returns (bool)',
  'event Approval(address indexed owner, address indexed spender, uint256 value)',
  'event StudentInitialTokensMinted(address indexed student, uint256 amount)',
] as const;
