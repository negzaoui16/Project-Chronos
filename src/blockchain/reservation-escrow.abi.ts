/**
 * Minimal ReservationEscrow ABI used by the backend.
 *
 * Signatures match contracts/ReservationEscrow.sol in chronos-blockchain.
 */
export const RESERVATION_ESCROW_ABI = [
  'function createReservation(address student, uint256 depositAmount) returns (uint256 reservationId)',
  'function releaseDeposit(uint256 reservationId)',
  'function slashDeposit(uint256 reservationId, uint256 penaltyAmount)',
  'function getReservation(uint256 reservationId) view returns (tuple(uint256 reservationId, address student, uint256 depositAmount, bool active, bool released, bool slashed, uint256 createdAt, uint256 releasedAt))',
  'function isReservationActive(uint256 reservationId) view returns (bool)',
  'function getLockedBalance() view returns (uint256)',
  'function chronosToken() view returns (address)',
  'function nextReservationId() view returns (uint256)',
  'event ReservationCreated(uint256 indexed reservationId, address indexed student, uint256 depositAmount)',
  'event DepositReleased(uint256 indexed reservationId, address indexed student, uint256 amount)',
  'event DepositSlashed(uint256 indexed reservationId, address indexed student, uint256 penaltyAmount, uint256 refundedAmount)',
] as const;
