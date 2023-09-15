#ifndef _CERTIFICATES_H_
#define _CERTIFICATES_H_

#ifdef __cplusplus
extern "C"
{
#endif

/* This file is auto-generated by the pycert_bearssl tool.  Do not change it manually.
 * Certificates are BearSSL br_x509_trust_anchor format.  Included certs:
 *
 * Index:    0
 * Label:    DST Root CA X3
 * Subject:  CN=DST Root CA X3,O=Digital Signature Trust Co.
 * Domain(s): api.opensensemap.org, ingress.opensensemap.org
 */

#define TAs_NUM 1

static const unsigned char TA_DN0[] = {
    0x30, 0x3f, 0x31, 0x24, 0x30, 0x22, 0x06, 0x03, 0x55, 0x04, 0x0a, 0x13,
    0x1b, 0x44, 0x69, 0x67, 0x69, 0x74, 0x61, 0x6c, 0x20, 0x53, 0x69, 0x67,
    0x6e, 0x61, 0x74, 0x75, 0x72, 0x65, 0x20, 0x54, 0x72, 0x75, 0x73, 0x74,
    0x20, 0x43, 0x6f, 0x2e, 0x31, 0x17, 0x30, 0x15, 0x06, 0x03, 0x55, 0x04,
    0x03, 0x13, 0x0e, 0x44, 0x53, 0x54, 0x20, 0x52, 0x6f, 0x6f, 0x74, 0x20,
    0x43, 0x41, 0x20, 0x58, 0x33,
};

static const unsigned char TA_RSA_N0[] = {
    0xdf, 0xaf, 0xe9, 0x97, 0x50, 0x08, 0x83, 0x57, 0xb4, 0xcc, 0x62, 0x65,
    0xf6, 0x90, 0x82, 0xec, 0xc7, 0xd3, 0x2c, 0x6b, 0x30, 0xca, 0x5b, 0xec,
    0xd9, 0xc3, 0x7d, 0xc7, 0x40, 0xc1, 0x18, 0x14, 0x8b, 0xe0, 0xe8, 0x33,
    0x76, 0x49, 0x2a, 0xe3, 0x3f, 0x21, 0x49, 0x93, 0xac, 0x4e, 0x0e, 0xaf,
    0x3e, 0x48, 0xcb, 0x65, 0xee, 0xfc, 0xd3, 0x21, 0x0f, 0x65, 0xd2, 0x2a,
    0xd9, 0x32, 0x8f, 0x8c, 0xe5, 0xf7, 0x77, 0xb0, 0x12, 0x7b, 0xb5, 0x95,
    0xc0, 0x89, 0xa3, 0xa9, 0xba, 0xed, 0x73, 0x2e, 0x7a, 0x0c, 0x06, 0x32,
    0x83, 0xa2, 0x7e, 0x8a, 0x14, 0x30, 0xcd, 0x11, 0xa0, 0xe1, 0x2a, 0x38,
    0xb9, 0x79, 0x0a, 0x31, 0xfd, 0x50, 0xbd, 0x80, 0x65, 0xdf, 0xb7, 0x51,
    0x63, 0x83, 0xc8, 0xe2, 0x88, 0x61, 0xea, 0x4b, 0x61, 0x81, 0xec, 0x52,
    0x6b, 0xb9, 0xa2, 0xe2, 0x4b, 0x1a, 0x28, 0x9f, 0x48, 0xa3, 0x9e, 0x0c,
    0xda, 0x09, 0x8e, 0x3e, 0x17, 0x2e, 0x1e, 0xdd, 0x20, 0xdf, 0x5b, 0xc6,
    0x2a, 0x8a, 0xab, 0x2e, 0xbd, 0x70, 0xad, 0xc5, 0x0b, 0x1a, 0x25, 0x90,
    0x74, 0x72, 0xc5, 0x7b, 0x6a, 0xab, 0x34, 0xd6, 0x30, 0x89, 0xff, 0xe5,
    0x68, 0x13, 0x7b, 0x54, 0x0b, 0xc8, 0xd6, 0xae, 0xec, 0x5a, 0x9c, 0x92,
    0x1e, 0x3d, 0x64, 0xb3, 0x8c, 0xc6, 0xdf, 0xbf, 0xc9, 0x41, 0x70, 0xec,
    0x16, 0x72, 0xd5, 0x26, 0xec, 0x38, 0x55, 0x39, 0x43, 0xd0, 0xfc, 0xfd,
    0x18, 0x5c, 0x40, 0xf1, 0x97, 0xeb, 0xd5, 0x9a, 0x9b, 0x8d, 0x1d, 0xba,
    0xda, 0x25, 0xb9, 0xc6, 0xd8, 0xdf, 0xc1, 0x15, 0x02, 0x3a, 0xab, 0xda,
    0x6e, 0xf1, 0x3e, 0x2e, 0xf5, 0x5c, 0x08, 0x9c, 0x3c, 0xd6, 0x83, 0x69,
    0xe4, 0x10, 0x9b, 0x19, 0x2a, 0xb6, 0x29, 0x57, 0xe3, 0xe5, 0x3d, 0x9b,
    0x9f, 0xf0, 0x02, 0x5d,
};

static const unsigned char TA_RSA_E0[] = {
    0x01, 0x00, 0x01,
};

static const br_x509_trust_anchor TAs[] = {
    {
        { (unsigned char *)TA_DN0, sizeof TA_DN0 },
        BR_X509_TA_CA,
        {
            BR_KEYTYPE_RSA,
            { .rsa = {
                (unsigned char *)TA_RSA_N0, sizeof TA_RSA_N0,
                (unsigned char *)TA_RSA_E0, sizeof TA_RSA_E0,
            } }
        }
    },
};

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* ifndef _CERTIFICATES_H_ */
