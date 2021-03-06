import os

from setuptools import find_packages, setup

_HERE = os.path.abspath(os.path.dirname(__file__))
with open(os.path.join(_HERE, 'README.md'), 'r') as f:
    long_desc = f.read()

setup(
    name='hyp3_insar_gamma',
    use_scm_version=True,
    description='HyP3 plugin to produce interferograms from a stack of Sentinel-1 data using GAMMA',
    long_description=long_desc,
    long_description_content_type='text/markdown',

    url='https://github.com/ASFHyP3/hyp3-insar-gamma',

    author='ASF APD/Tools Team',
    author_email='uaf-asf-apd@alaska.edu',

    license='BSD',
    include_package_data=True,

    classifiers=[
        'Intended Audience :: Science/Research',
        'License :: OSI Approved :: BSD License',
        'Natural Language :: English',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.6',
        ],

    python_requires='~=3.6',

    install_requires=[
        'hyp3lib>=1.6.1,<2',
        'importlib_metadata',
        'lxml',
    ],

    extras_require={
        'develop': [
            'pytest',
            'pytest-cov',
            'pytest-console-scripts',
        ]
    },

    packages=find_packages(),

    entry_points={'console_scripts': [
            'insar_gamma = hyp3_insar_gamma.__main__:main',
            'ifm_sentinel.py = hyp3_insar_gamma.ifm_sentinel:main',
            'interf_pwr_s1_lt_tops_proc.py = hyp3_insar_gamma.interf_pwr_s1_lt_tops_proc:main',
            'unwrapping_geocoding.py = hyp3_insar_gamma.unwrapping_geocoding:main',
        ]
    },

    zip_safe=False,
)
