# AssetTimeCapsule

**AssetTimeCapsule** is a blockchain-based time capsule system built on the Stacks blockchain using Clarity 2.0 smart contracts. The system is designed to manage the time-bound transfer of assets with conditional phase-based releases. It includes a variety of features to handle asset transfers, milestone tracking, dispute management, and emergency retrieval mechanisms.

## Features

- **Time-bound asset transfers**: Assets are transferred in a time-sensitive manner based on predefined unlock heights and phases.
- **Conditional releases**: Assets are released in stages, following specified conditions per phase.
- **Multi-recipient capsules**: Allows asset distribution across multiple recipients with configurable portions.
- **Dispute management**: Contest functionality to allow for resolution of disputes related to capsule management.
- **Phase progress tracking**: Recipients can report progress on individual phases, ensuring transparency.
- **Emergency retrieval**: Admins can retrieve assets if certain conditions (e.g., expiration) are met.
- **Creator control**: Capsule creators can terminate, extend, or augment the asset capsules as needed.
- **Verified recipient directory**: Ensures only certified recipients can interact with the capsules.
- **Protection mechanisms**: Includes guardrails to prevent malicious behavior, such as asset theft or sudden transfers.

## Smart Contract Features

- **Capsules Registry**: The contract tracks individual time capsules, including their status, recipient, quantity, and phase progress.
- **Multi-Recipient Capsules**: Supports asset distribution to multiple recipients with specific proportions.
- **Admin Functions**: Includes various administrative operations such as approving phases, managing proxies, and retrieving expired assets.
- **Security Features**: Capsule creation requires certified recipients, and protections such as rate limiting are implemented to ensure fair usage.

## Usage

### 1. Create a New Capsule
You can create a new time capsule by specifying the recipient, the quantity of assets to be transferred, and the number of phases for the release.

```clojure
(create-capsule recipient principal, quantity uint, phases (list 5 uint))
```

### 2. Approve Phase Completion
Admins can approve the completion of a phase and release the corresponding portion of assets to the recipient.

```clojure
(approve-phase capsule-id uint)
```

### 3. Prolong Capsule Duration
You can extend the capsule's unlock time to ensure the assets remain locked for a longer duration.

```clojure
(prolong-capsule capsule-id uint extension-blocks uint)
```

### 4. Emergency Retrieval
If necessary, admins can retrieve assets from expired capsules and return them to the original creator.

```clojure
(retrieve-assets capsule-id uint)
```

### 5. Multi-Recipient Capsule
This feature allows the creator to specify multiple recipients and distribute assets proportionally.

```clojure
(create-multi-capsule targets (list 5 { recipient: principal, portion: uint }), quantity uint)
```

### 6. Contest and Dispute
Capsules can be contested, and disputes can be resolved with a specified bond.

```clojure
(capsule-contest capsule-id uint contest-grounds string, contest-bond uint)
```

## Security Considerations

- **Role-based permissions**: Only the creator or an admin can perform critical operations such as terminating a capsule or modifying its contents.
- **Rate limiting**: Operations like transferring large quantities or rapid transfers are limited to prevent abuse.
- **Protection against anomalies**: Automated detection of unusual activity patterns, such as high-frequency transfers or abnormal contest submissions.

## Installation

1. **Install Stacks CLI**: Ensure you have the [Stacks CLI](https://docs.stacks.co/tools/cli) installed.
2. **Deploy to Stacks**: Deploy the smart contract to the Stacks blockchain using the Clarity CLI or integrate it with your Stacks-compatible dApp.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
