// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import '@openzeppelin/contracts/utils/Base64.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

/// @title ReceiptRenderer
/// @author RabbitHole.gg
/// @dev This contract is used to render on-chain data for RabbitHole Receipts (ERC-721 standard)
contract ReceiptRenderer {
    using Strings for uint256;

    /// @dev generates the tokenURI for a given ERC-721 token ID
    /// @param tokenId_ The token id to generate the URI for
    /// @param questId_ The questId tied to the tokenId
    /// @param totalParticipants_ The total number of participants in the quest
    /// @param claimed_ Whether or not the token has been claimed
    /// @param rewardAmount_ The amount of reward tokens that the user is eligible for
    /// @param rewardAddress_ The address of the reward token
    /// @return encoded JSON following the generic OpenSea metadata standard
    function generateTokenURI(
        uint tokenId_,
        string memory questId_,
        uint totalParticipants_,
        bool claimed_,
        uint rewardAmount_,
        address rewardAddress_
    ) external view virtual returns (string memory) {
        bytes memory dataURI = generateDataURI(
            tokenId_,
            questId_,
            totalParticipants_,
            claimed_,
            rewardAmount_,
            rewardAddress_
        );
        return string(abi.encodePacked('data:application/json;base64,', Base64.encode(dataURI)));
    }

    function generateDataURI(
        uint tokenId_,
        string memory questId_,
        uint totalParticipants_,
        bool claimed_,
        uint rewardAmount_,
        address rewardAddress_
    ) internal view virtual returns (bytes memory) {
        string memory tokenIdString = tokenId_.toString();

        bytes memory attributes = abi.encodePacked(
            '[',
            generateAttribute('Quest ID', questId_),
            ',',
            generateAttribute('Token ID', tokenIdString),
            ',',
            generateAttribute('Total Participants', totalParticipants_.toString()),
            ',',
            generateAttribute('Claimed', claimed_ ? 'true' : 'false'),
            ',',
            generateAttribute('Reward Amount', rewardAmount_.toString()),
            ',',
            generateAttribute('Reward Address', Strings.toHexString(uint160(rewardAddress_), 20)),
            ']'
        );
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "RabbitHole.gg Receipt #',
            tokenIdString,
            '",',
            '"description": "RabbitHole.gg Receipts are used to claim rewards from completed quests.",',
            '"image": "',
            generateSVG(claimed_, questId_, rewardAmount_, rewardAddress_),
            '",',
            '"attributes": ',
            attributes,
            '}'
        );
        return dataURI;
    }

    /// @dev generates an attribute object for an ERC-721 token
    /// @param key The key for the attribute
    /// @param value The value for the attribute
    function generateAttribute(string memory key, string memory value) internal pure returns (string memory) {
        bytes memory attribute = abi.encodePacked(
            '{',
            '"trait_type": "',
            key,
            '",',
            '"value": "',
            value,
            '"',
            '}'
        );
        return string(attribute);
    }

    /// @dev generates the on-chain SVG for an ERC-721 token ID
    /// @param claimed_ Whether or not the token has been claimed
    /// @param questId_ The questId tied to the tokenId
    /// @param rewardAmount_ The amount of reward tokens that the user is eligible for
    /// @param rewardAddress_ The address of the reward token
    /// @return base64 encoded SVG image
    function generateSVG(bool claimed_, string memory questId_, uint rewardAmount_, address rewardAddress_) internal view returns (string memory) {
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="648" height="889" fill="none">',
            '<style><![CDATA[.B{fill-rule:evenodd}.C{color-interpolation-filters:sRGB}.D{flood-opacity:0}.E{fill-opacity:.5}.F{stroke:#ad86ff}.G{stroke-width:2}.H{fill:#dae0ff}.I{font-family:Arial}.J{text-anchor:middle}.K{shape-rendering:crispEdges}.L{dominant-baseline:middle}]]></style><g filter="url(#B)"><path d="M91.731 44.195c-25.957 0-47 21.043-47 47v114c0 25.958 21.043 47 47 47H220.23v384H91.731c-25.957 0-47 21.043-47 47v114c0 25.958 21.043 47 47 47h465c25.958 0 47-21.042 47-47v-114c0-25.957-21.042-47-47-47h-128.5v-384h128.5c25.958 0 47-21.042 47-47v-114c0-25.957-21.042-47-47-47H91.731z" fill="#0f0f16" class="B"/><path d="M220.73 252.195v-.5h-.5H91.731c-25.681 0-46.5-20.818-46.5-46.5v-114c0-25.681 20.819-46.5 46.5-46.5h465c25.682 0 46.5 20.819 46.5 46.5v114c0 25.682-20.818 46.5-46.5 46.5h-128.5-.5v.5 384 .5h.5 128.5c25.682 0 46.5 20.819 46.5 46.5v114c0 25.682-20.818 46.5-46.5 46.5H91.731c-25.681 0-46.5-20.818-46.5-46.5v-114c0-25.681 20.819-46.5 46.5-46.5H220.23h.5v-.5-384z" stroke="#232854"/></g><mask id="A" fill="#fff"><path d="M44.731 91.195c0-25.957 21.043-47 47-47h465c25.958 0 47 21.043 47 47v114c0 21.448-14.365 39.54-34 45.179v387.642c19.635 5.64 34 23.732 34 45.179v114c0 25.958-21.042 47-47 47H91.731c-25.957 0-47-21.042-47-47v-114c0-21.81 14.856-40.15 35-45.454V250.65c-20.145-5.304-35-23.645-35-45.455v-114z" class="B"/></mask><path d="M569.73 250.374l-.276-.961-.724.208v.753h1zm0 387.642h-1v.754l.724.207.276-.961zm-489.999-.275l.255.967.745-.196v-.771h-1zm0-387.091h1v-.771l-.745-.197-.255.968zm12-207.455c-26.51 0-48 21.49-48 48h2c0-25.405 20.595-46 46-46v-2zm465 0H91.731v2h465v-2zm48 48c0-26.51-21.49-48-48-48v2c25.406 0 46 20.595 46 46h2zm0 114v-114h-2v114h2zm-34.723 46.14c20.051-5.759 34.723-24.234 34.723-46.14h-2c0 20.99-14.059 38.699-33.276 44.218l.553 1.922zm.723 386.681V250.374h-2v387.642h2zm34 45.179c0-21.905-14.672-40.381-34.723-46.14l-.553 1.922c19.217 5.52 33.276 23.229 33.276 44.218h2zm0 114v-114h-2v114h2zm-48 48c26.51 0 48-21.49 48-48h-2c0 25.405-20.594 46-46 46v2zm-464.999 0h465v-2H91.731v2zm-48-48c0 26.51 21.49 48 48 48v-2c-25.405 0-46-20.595-46-46h-2zm0-114v114h2v-114h-2zm35.745-46.421c-20.573 5.417-35.745 24.146-35.745 46.421h2c0-21.344 14.539-39.296 34.255-44.487l-.509-1.934zm-.745-386.124v387.091h2V250.65h-2zm-35-45.455c0 22.276 15.173 41.005 35.745 46.422l.509-1.935c-19.716-5.191-34.255-23.142-34.255-44.487h-2zm0-114v114h2v-114h-2z" fill="#232854" mask="url(#A)"/><g filter="url(#C)" class="B K"><use xlink:href="#M" fill="#000" fill-opacity=".01"/></g><use xlink:href="#M" fill="#0c0b0f" fill-opacity=".26" class="B"/><g style="mix-blend-mode:color-dodge" filter="url(#D)" class="B K"><use xlink:href="#M" fill="url(#H)" fill-opacity=".99"/></g><use xlink:href="#N" fill="url(#I)" style="mix-blend-mode:color-dodge" class="E"/><use xlink:href="#N" fill="url(#J)" style="mix-blend-mode:color-dodge" class="E"/><use xlink:href="#N" fill="url(#K)" style="mix-blend-mode:color-dodge" class="E"/><use xlink:href="#N" fill="url(#L)" style="mix-blend-mode:color-dodge" class="E"/><use xlink:href="#N" class="F G"/><path d="M81.425 695.195H569.27v58.5l-35.76 37.131-452.085.369v-96z" fill="#ad86ff"/><path d="M325.231 315.009l-.001-236.802m-7.5 236.265V95.892l-18.5-18.697m33.5 237.277V95.892l18.5-18.697m-40.5 237.545V99.43l-22-22.234m52 237.277V99.43l22-22.234m-36.5 331.666l-.001 170.565m7.501-170.565v152.88l18.5 18.697m-33.5-171.577v152.88l-18.5 18.697m40.5-171.242v149.007l22 22.235m-52-171.775v149.54l-22 22.235m-66.683-266.243H422.67l29.6 47.5-29.6 47.5H222.047l-28.777-47.5 28.777-47.5zm.223 297.5c0-17.397 14.103-31.5 31.5-31.5h140c17.397 0 31.5 14.103 31.5 31.5s-14.103 31.5-31.5 31.5h-140c-17.397 0-31.5-14.103-31.5-31.5zm102 83.499v95m-245-96h488" class="F G"/><path d="M508.022 178.34c10.803-4.323 18.45-15.029 18.45-27.55 0-16.345-13.029-29.595-29.101-29.595s-29.101 13.25-29.101 29.595c0 10.385 5.259 19.52 13.217 24.802.566-1.02 1.612-1.705 2.809-1.705.265 0 .488-.247.422-.504a20.47 20.47 0 0 1-.644-5.115c0-10.652 8.105-19.287 18.104-19.287.687 0 1.293-.463 1.522-1.111l.058-.158c.471-1.26-.314-3.043-1.625-3.345-6.7-1.545-12.016-7.022-13.688-14.036-.192-.805.714-1.341 1.373-.839l26.416 20.097c.287.218.421.583.358.939-.181 1.021-.276 2.075-.276 3.152 0 1.334.146 2.633.42 3.878.079.361-.043.742-.348.951a8.24 8.24 0 0 1-4.662 1.447c-1.397 0-2.716-.351-3.88-.973-.344-.184-.74-.255-1.119-.165-.652.155-1.112.738-1.112 1.408v12.169c0 .516-.418.934-.934.934h-1.506c-.504 0-.912-.4-.978-.899-.56-4.229-3.973-7.483-8.101-7.483-.262 0-.521.013-.777.039-.304.03-.524.294-.524.6 0 .335.264.607.596.653 3.399.471 6.024 3.553 6.024 7.285a7.83 7.83 0 0 1-.137 1.464c-.101.527.278 1.059.815 1.059h.762a.02.02 0 0 1 .02.02.02.02 0 0 0 .02.02h5.894c.065 0 .128.025.174.071h0a15.52 15.52 0 0 1 .509.52c.35.38.492.915.55 1.662zm-27.419-31.65c-.488-.389-.193-1.126.431-1.126h16.626c.624 0 .919.737.431 1.126-2.436 1.94-5.463 3.089-8.744 3.089s-6.309-1.149-8.744-3.089zm31.5 5.303c0 .922-.705 1.669-1.575 1.669s-1.575-.747-1.575-1.669.705-1.669 1.575-1.669 1.575.748 1.575 1.669z" class="B H"/>',
            this.generateTextFields(claimed_, questId_, rewardAmount_, rewardAddress_),
            '<g class="F G"><use xlink:href="#O"/><use xlink:href="#O" x="-353"/><use xlink:href="#O" y="256"/><use xlink:href="#O" x="-353" y="256"/></g><defs><filter id="B" x=".73" y=".195" width="647" height="888" filterUnits="userSpaceOnUse" class="C"><feFlood class="D"/><feBlend in="SourceGraphic"/><feGaussianBlur stdDeviation="22"/></filter><filter id="C" x="13.816" y="10.195" width="622" height="847" filterUnits="userSpaceOnUse" class="C"><feFlood result="A" class="D"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="B"/><feOffset/><feGaussianBlur stdDeviation="1"/><feComposite in2="B" operator="out"/><feColorMatrix values="0 0 0 0 0.756 0 0 0 0 0.2375 0 0 0 0 1 0 0 0 1 0"/><feBlend in2="A" result="C"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="B"/><feOffset/><feGaussianBlur stdDeviation="33"/><feComposite in2="B" operator="out"/><feColorMatrix values="0 0 0 0 0.6095 0 0 0 0 0.1125 0 0 0 0 1 0 0 0 0.83 0"/><feBlend in2="C"/><feBlend in="SourceGraphic" result="E"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="B"/><feOffset/><feGaussianBlur stdDeviation="1"/><feComposite in2="B" operator="arithmetic" k2="-1" k3="1"/><feColorMatrix values="0 0 0 0 0.63 0 0 0 0 0.5375 0 0 0 0 1 0 0 0 1 0"/><feBlend in2="E"/></filter><filter id="D" x="75.816" y="76.195" width="498" height="723" filterUnits="userSpaceOnUse" class="C"><feFlood result="A" class="D"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="B"/><feOffset dy="4"/><feGaussianBlur stdDeviation="2"/><feComposite in2="B" operator="out"/><feColorMatrix values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0"/><feBlend in2="A"/><feBlend in="SourceGraphic"/></filter><filter id="E" y="675.584" height="136.611" filterUnits="userSpaceOnUse" x="100" width="450" class="C"><feFlood result="A" class="D"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="B"/><feOffset/><feGaussianBlur stdDeviation="1.5"/><feComposite in2="B" operator="out"/><feColorMatrix values="0 0 0 0 0.966867 0 0 0 0 0.585833 0 0 0 0 1 0 0 0 0.87 0"/><feBlend in2="A" result="C"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="B"/><feOffset/><feGaussianBlur stdDeviation="29.5"/><feComposite in2="B" operator="out"/><feColorMatrix values="0 0 0 0 0.624167 0 0 0 0 0.145833 0 0 0 0 1 0 0 0 0.91 0"/><feBlend in2="C"/><feBlend in="SourceGraphic"/></filter><filter id="F" x="203.166" y="543.389" width="243.62" height="136.916" filterUnits="userSpaceOnUse" class="C"><feFlood result="A" class="D"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="B"/><feOffset/><feGaussianBlur stdDeviation="1.5"/><feComposite in2="B" operator="out"/><feColorMatrix values="0 0 0 0 0.966867 0 0 0 0 0.585833 0 0 0 0 1 0 0 0 0.87 0"/><feBlend in2="A" result="C"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="B"/><feOffset/><feGaussianBlur stdDeviation="29.5"/><feComposite in2="B" operator="out"/><feColorMatrix values="0 0 0 0 0.624167 0 0 0 0 0.145833 0 0 0 0 1 0 0 0 0.91 0"/><feBlend in2="C"/><feBlend in="SourceGraphic"/></filter><filter id="G" x="196.876" y="290.619" width="247.7" height="147.062" filterUnits="userSpaceOnUse" class="C"><feFlood result="A" class="D"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="B"/><feOffset/><feGaussianBlur stdDeviation="1.5"/><feComposite in2="B" operator="out"/><feColorMatrix values="0 0 0 0 0.966867 0 0 0 0 0.585833 0 0 0 0 1 0 0 0 0.87 0"/><feBlend in2="A" result="C"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="B"/><feOffset/><feGaussianBlur stdDeviation="29.5"/><feComposite in2="B" operator="out"/><feColorMatrix values="0 0 0 0 0.624167 0 0 0 0 0.145833 0 0 0 0 1 0 0 0 0.91 0"/><feBlend in2="C"/><feBlend in="SourceGraphic"/></filter><radialGradient id="H" cx="0" cy="0" r="1" gradientTransform="matrix(784.184,0,0,761.17,325.816,380.195)" xlink:href="#P"><stop offset=".01" stop-color="#bd00ff" stop-opacity=".39"/><stop offset=".135" stop-color="#ec7bff" stop-opacity=".22"/><stop offset=".271" stop-color="#f25aff" stop-opacity=".48"/><stop offset="1" stop-color="#010039" stop-opacity=".69"/></radialGradient><radialGradient id="I" cx="0" cy="0" r="1" gradientTransform="translate(320.316 57.1953) rotate(88.6238) scale(333.096 579.761)" xlink:href="#P"><stop stop-color="#8f00ff" stop-opacity=".51"/><stop offset="1" stop-color="#1c231b" stop-opacity="0"/><stop offset="1" stop-opacity="0"/></radialGradient><radialGradient id="J" cx="0" cy="0" r="1" gradientTransform="matrix(2.112515728529184e-14,-345,877.774,5.3748155973738444e-14,327.816,815.695)" xlink:href="#P"><stop stop-color="#c13fff"/><stop offset="1" stop-color="#1c231b" stop-opacity="0"/><stop offset="1" stop-color="#c00dff" stop-opacity="0"/></radialGradient><radialGradient id="K" cx="0" cy="0" r="1" gradientTransform="matrix(267.9995372733712,-2.0000175646580165,8.572090192313523,1148.648014698034,64.3164,384.195)" xlink:href="#P"><stop stop-color="#b946ff"/><stop offset="1" stop-color="#1c231b" stop-opacity="0"/><stop offset="1" stop-color="#860dff" stop-opacity="0"/></radialGradient><radialGradient id="L" cx="0" cy="0" r="1" gradientTransform="matrix(-242,2.963645253936595e-14,-1.5644005606348036e-13,-1277.43,574.316,382.195)" xlink:href="#P"><stop stop-color="#dd0fff" stop-opacity=".91"/><stop offset="1" stop-color="#1c231b" stop-opacity="0"/><stop offset="1" stop-color="#a30dff" stop-opacity="0"/></radialGradient><path id="M" d="M413.387 76.195H239.246c-2.264 9.741-10.999 17-21.43 17h-39c-10.43 0-19.165-7.259-21.429-17h-43.979l-33.592 33.592v681.408h453.501l36.499-36.5v-641l-37.5-37.5h-37.07c-2.264 9.741-10.999 17-21.43 17h-39c-10.43 0-19.165-7.259-21.429-17z"/><path id="N" d="M217.816 94.195c10.628 0 19.57-7.207 22.21-17h172.581c2.64 9.793 11.582 17 22.209 17h39c10.628 0 19.57-7.207 22.21-17h35.876l36.914 36.915v640.171l-35.914 35.914H80.816V110.201l33.006-33.006h42.785c2.64 9.793 11.582 17 22.209 17h39z"/><path id="O" d="M499 351v12m0 0v12m0-12h-12m12 0h12m-12 7a7 7 0 1 1 0-14 7 7 0 1 1 0 14z"/><linearGradient id="P" gradientUnits="userSpaceOnUse"/></defs>',
            '</svg>'
        );
        return string(abi.encodePacked('data:image/svg+xml;base64,', Base64.encode(svg)));
    }

    /// @dev generates the SVG parts that include the text fields
    /// @param claimed_ Whether or not the token has been claimed
    /// @param questId_ The questId tied to the tokenId
    /// @param rewardAmount_ The amount of reward tokens that the user is eligible for
    /// @param rewardAddress_ The address of the reward token
    /// @return SVG parts that include the text fields
    function generateTextFields(bool claimed_, string memory questId_, uint rewardAmount_, address rewardAddress_) external view returns (string memory) {
        bytes memory text = abi.encodePacked(
            '<g filter="url(#E)" class="I"><text fill="#0f0f16" xml:space="preserve" style="white-space:pre" font-size="26" font-weight="bold" letter-spacing="0.07em"><tspan y="750" x="325" class="J">',
            claimed_ ? 'CLAIMED' : 'REDEEMABLE',
            '</tspan></text></g>',
            '<g filter="url(#F)" class="H I J L"><text font-size="26" letter-spacing="0em" x="50%" y="615"><tspan>RabbitHole</tspan></text></g>',
            '<g filter="url(#G)" class="H I J L"><text font-size="39.758" letter-spacing="0.05em" x="50%" y="365">',
            this.humanRewardAmountAndSymbol(rewardAmount_, rewardAddress_),
            '</text></g>'
        );

        return string(text);
    }

    /// @dev Returns a human readable reward amount and symbol
    /// @param rewardAmount_ The reward amount
    /// @param rewardAddress_ The reward address
    function humanRewardAmountAndSymbol(uint rewardAmount_, address rewardAddress_) external view returns (string memory) {
        string memory symbol;
        uint8 decimals;

        if (rewardAddress_ == address(0)) {
            symbol = 'ETH';
            decimals = 18;
        } else {
            symbol = ERC20(rewardAddress_).symbol();
            decimals = ERC20(rewardAddress_).decimals();
        }

        return string(abi.encodePacked(decimalString(rewardAmount_, decimals, false), ' ', symbol));
    }

    /// @notice From https://gist.github.com/wilsoncusack/d2e680e0f961e36393d1bf0b6faafba7
    struct DecimalStringParams {
        // significant figures of decimal
        uint256 sigfigs;
        // length of decimal string
        uint8 bufferLength;
        // ending index for significant figures (funtion works backwards when copying sigfigs)
        uint8 sigfigIndex;
        // index of decimal place (0 if no decimal)
        uint8 decimalIndex;
        // start index for trailing/leading 0's for very small/large numbers
        uint8 zerosStartIndex;
        // end index for trailing/leading 0's for very small/large numbers
        uint8 zerosEndIndex;
        // true if decimal number is less than one
        bool isLessThanOne;
        // true if string should include "%"
        bool isPercent;
    }

    function decimalString(uint256 number, uint8 decimals, bool isPercent) internal pure returns (string memory){
        uint8 percentBufferOffset = isPercent ? 1 : 0;
        uint256 tenPowDecimals = 10 ** decimals;
        uint256 temp = number;
        uint8 digits;
        uint8 numSigfigs;
        while (temp != 0) {
            if (numSigfigs > 0) {
                // count all digits preceding least significant figure
                numSigfigs++;
            } else if (temp % 10 != 0) {
                numSigfigs++;
            }
            digits++;
            temp /= 10;
        }

        DecimalStringParams memory params;
        params.isPercent = isPercent;
        if ((digits - numSigfigs) >= decimals) {
            // no decimals, ensure we preserve all trailing zeros
            params.sigfigs = number / tenPowDecimals;
            params.sigfigIndex = digits - decimals;
            params.bufferLength = params.sigfigIndex + percentBufferOffset;
        } else {
            // chop all trailing zeros for numbers with decimals
            params.sigfigs = number / (10 ** (digits - numSigfigs));
            if (tenPowDecimals > number) {
                // number is less tahn one
                // in this case, there may be leading zeros after the decimal place
                // that need to be added

                // offset leading zeros by two to account for leading '0.'
                params.zerosStartIndex = 2;
                params.zerosEndIndex = decimals - digits + 2;
                params.sigfigIndex = numSigfigs + params.zerosEndIndex;
                params.bufferLength = params.sigfigIndex + percentBufferOffset;
                params.isLessThanOne = true;
            } else {
                // In this case, there are digits before and
                // after the decimal place
                params.sigfigIndex = numSigfigs + 1;
                params.decimalIndex = digits - decimals + 1;
            }
        }
        params.bufferLength = params.sigfigIndex + percentBufferOffset;
        return generateDecimalString(params);
    }

    function generateDecimalString(DecimalStringParams memory params) private pure returns (string memory) {
        bytes memory buffer = new bytes(params.bufferLength);
        if (params.isPercent) {
            buffer[buffer.length - 1] = '%';
        }
        if (params.isLessThanOne) {
            buffer[0] = '0';
            buffer[1] = '.';
        }

        // add leading/trailing 0's
        for (uint256 zerosCursor = params.zerosStartIndex; zerosCursor < params.zerosEndIndex; zerosCursor++) {
            buffer[zerosCursor] = bytes1(uint8(48));
        }
        // add sigfigs
        while (params.sigfigs > 0) {
            if (params.decimalIndex > 0 && params.sigfigIndex == params.decimalIndex) {
                buffer[--params.sigfigIndex] = '.';
            }
            buffer[--params.sigfigIndex] = bytes1(uint8(uint256(48) + (params.sigfigs % 10)));
            params.sigfigs /= 10;
        }
        return string(buffer);
    }
}